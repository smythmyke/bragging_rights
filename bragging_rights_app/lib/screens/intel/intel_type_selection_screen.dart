import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/injury_service.dart';

class IntelTypeSelectionScreen extends StatefulWidget {
  final String? gameId;
  final String gameTitle;
  final String sport;
  final String? homeTeamId;
  final String? awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? gameTime;

  const IntelTypeSelectionScreen({
    Key? key,
    this.gameId,
    required this.gameTitle,
    required this.sport,
    this.homeTeamId,
    this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.gameTime,
  }) : super(key: key);

  @override
  State<IntelTypeSelectionScreen> createState() => _IntelTypeSelectionScreenState();
}

class _IntelTypeSelectionScreenState extends State<IntelTypeSelectionScreen> {
  bool _isLoadingInjuryStats = true;
  int _homeInjuryCount = 0;
  int _awayInjuryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInjuryStats();
  }

  Future<void> _loadInjuryStats() async {
    if (widget.homeTeamId == null || widget.awayTeamId == null) {
      print('[IntelTypes] Missing team IDs, cannot load injury stats');
      setState(() => _isLoadingInjuryStats = false);
      return;
    }

    final injuryService = InjuryService();

    try {
      // Fetch injury counts for preview
      final report = await injuryService.getGameInjuries(
        sport: 'basketball',
        homeTeamId: widget.homeTeamId!,
        homeTeamName: widget.homeTeamName,
        awayTeamId: widget.awayTeamId!,
        awayTeamName: widget.awayTeamName,
      );

      setState(() {
        _homeInjuryCount = report?.homeInjuries.length ?? 0;
        _awayInjuryCount = report?.awayInjuries.length ?? 0;
        _isLoadingInjuryStats = false;
      });
    } catch (e) {
      print('[IntelTypes] Error loading injury stats: $e');
      setState(() => _isLoadingInjuryStats = false);
    }
  }

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
              'Game Intelligence',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Select Intelligence Type',
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
            child: _buildIntelTypeGrid(),
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

  Widget _buildIntelTypeGrid() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'AVAILABLE INTELLIGENCE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),

        // Injury Intel Tile (Available)
        _buildIntelTypeTile(
          icon: Icons.healing,
          iconColor: const Color(0xFFFF4B4B),
          title: 'Injury Intel',
          subtitle: 'Complete injury reports',
          description: 'Get detailed injury reports for both teams including player status, injury type, expected return dates, and game impact analysis.',
          isAvailable: true,
          isLoading: _isLoadingInjuryStats,
          stats: _isLoadingInjuryStats
              ? null
              : [
                  IntelStat('${_homeInjuryCount + _awayInjuryCount}', 'Total'),
                  IntelStat('$_homeInjuryCount', widget.homeTeamName),
                  IntelStat('$_awayInjuryCount', widget.awayTeamName),
                ],
          onTap: () => _navigateToInjuryPurchase(),
        ),

        // Advanced Analytics Tile (Coming Soon)
        _buildIntelTypeTile(
          icon: Icons.bar_chart,
          iconColor: AppTheme.primaryCyan,
          title: 'Advanced Analytics',
          subtitle: 'Win probability & momentum',
          description: 'Real-time win probability charts, momentum tracking, and advanced team efficiency ratings.',
          isAvailable: false,
          comingSoon: true,
          onTap: null,
        ),

        // Betting Insights Tile (Coming Soon)
        _buildIntelTypeTile(
          icon: Icons.insights,
          iconColor: const Color(0xFF00FF88),
          title: 'Betting Insights',
          subtitle: 'ATS records & trends',
          description: 'Against the spread performance, over/under trends, and historical betting outcomes.',
          isAvailable: false,
          comingSoon: true,
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildIntelTypeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
    required bool isAvailable,
    bool isLoading = false,
    List<IntelStat>? stats,
    bool comingSoon = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isAvailable && !isLoading ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isAvailable
              ? LinearGradient(
                  colors: [
                    AppTheme.surfaceBlue.withOpacity(0.8),
                    AppTheme.surfaceBlue.withOpacity(0.6),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.shade800.withOpacity(0.3),
                    Colors.grey.shade900.withOpacity(0.3),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable
                ? AppTheme.primaryCyan.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
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
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                  )
                else if (isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            if (stats != null && stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.primaryCyan.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: stats
                      .map((stat) => Expanded(
                            child: _buildStatItem(stat),
                          ))
                      .toList(),
                ),
              ),
            ] else if (isLoading) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IntelStat stat) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToInjuryPurchase() {
    Navigator.pushNamed(
      context,
      '/injury_intel_purchase',
      arguments: {
        'gameId': widget.gameId,
        'gameTitle': widget.gameTitle,
        'sport': widget.sport,
        'homeTeamId': widget.homeTeamId,
        'awayTeamId': widget.awayTeamId,
        'homeTeamName': widget.homeTeamName,
        'awayTeamName': widget.awayTeamName,
        'gameTime': widget.gameTime,
        'homeInjuryCount': _homeInjuryCount,
        'awayInjuryCount': _awayInjuryCount,
      },
    );
  }
}

class IntelStat {
  final String value;
  final String label;

  IntelStat(this.value, this.label);
}
