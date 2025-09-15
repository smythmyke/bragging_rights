import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/team_logo_service.dart';
import '../services/team_name_mapper.dart';
import '../theme/app_theme.dart';

enum BetType {
  moneyline,
  spread,
  total,
  prop,
}

class TeamBetCard extends StatefulWidget {
  final String teamName;
  final String sport;
  final String title;
  final String odds;
  final String description;
  final Color color;
  final BetType type;
  final String betId;
  final bool isSelected;
  final bool wasAlreadyPlaced;
  final VoidCallback onTap;
  final bool isPremium;
  
  const TeamBetCard({
    super.key,
    required this.teamName,
    required this.sport,
    required this.title,
    required this.odds,
    required this.description,
    required this.color,
    required this.type,
    required this.betId,
    required this.isSelected,
    required this.wasAlreadyPlaced,
    required this.onTap,
    this.isPremium = false,
  });

  @override
  State<TeamBetCard> createState() => _TeamBetCardState();
}

class _TeamBetCardState extends State<TeamBetCard> {
  final TeamLogoService _logoService = TeamLogoService();
  TeamLogoData? _logoData;
  bool _isLoadingLogo = true;

  @override
  void initState() {
    super.initState();
    _loadTeamLogo();
  }

  @override
  void didUpdateWidget(TeamBetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamName != widget.teamName || oldWidget.sport != widget.sport) {
      _loadTeamLogo();
    }
  }

  Future<void> _loadTeamLogo() async {
    // Determine league based on sport
    String? league;
    final sportLower = widget.sport.toLowerCase();

    if (sportLower.contains('soccer') || sportLower.contains('premier') || sportLower.contains('epl')) {
      league = 'EPL';
    } else if (sportLower.contains('nfl') || sportLower.contains('football')) {
      league = 'NFL';
    } else if (sportLower.contains('nba') || sportLower.contains('basketball')) {
      league = 'NBA';
    } else if (sportLower.contains('mlb') || sportLower.contains('baseball')) {
      league = 'MLB';
    } else if (sportLower.contains('nhl') || sportLower.contains('hockey')) {
      league = 'NHL';
    } else if (sportLower.contains('mls')) {
      league = 'MLS';
    }

    debugPrint('TeamBetCard: Loading logo for ${widget.teamName} in ${widget.sport} (league: $league)');

    try {
      final logoData = await _logoService.getTeamLogo(
        teamName: widget.teamName,
        sport: widget.sport,
        league: league,
      );

      if (mounted) {
        if (logoData != null) {
          debugPrint('TeamBetCard: Logo found for ${widget.teamName}: ${logoData.logoUrl}');
        } else {
          debugPrint('TeamBetCard: No logo found for ${widget.teamName}');
        }
        setState(() {
          _logoData = logoData;
          _isLoadingLogo = false;
        });
      }
    } catch (e) {
      debugPrint('TeamBetCard: Error loading team logo for ${widget.teamName}: $e');
      if (mounted) {
        setState(() {
          _isLoadingLogo = false;
        });
      }
    }
  }

  Widget _buildLogoWidget() {
    if (_isLoadingLogo) {
      return Container(
        width: 60,
        height: 60,
        padding: const EdgeInsets.all(16),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_logoData != null && _logoData!.logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _logoData!.logoUrl,
        width: 60,
        height: 60,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(16),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => _buildFallbackLogo(),
      );
    }

    return _buildFallbackLogo();
  }
  
  String _getSportCode(String sport) {
    final sportLower = sport.toLowerCase();
    if (sportLower.contains('nba') || sportLower.contains('basketball')) return 'nba';
    if (sportLower.contains('nfl') || sportLower.contains('football')) return 'nfl';
    if (sportLower.contains('mlb') || sportLower.contains('baseball')) return 'mlb';
    if (sportLower.contains('nhl') || sportLower.contains('hockey')) return 'nhl';
    if (sportLower.contains('soccer') || sportLower.contains('premier') || sportLower.contains('mls')) return 'soccer';
    return 'generic';
  }
  
  
  Widget _buildFallbackLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getSportIcon(widget.sport),
        color: widget.color,
        size: 30,
      ),
    );
  }
  
  IconData _getSportIcon(String sport) {
    final sportLower = sport.toLowerCase();
    if (sportLower.contains('basketball')) return Icons.sports_basketball;
    if (sportLower.contains('football')) return Icons.sports_football;
    if (sportLower.contains('baseball')) return Icons.sports_baseball;
    if (sportLower.contains('hockey')) return Icons.sports_hockey;
    if (sportLower.contains('soccer')) return Icons.sports_soccer;
    if (sportLower.contains('tennis')) return Icons.sports_tennis;
    if (sportLower.contains('golf')) return Icons.sports_golf;
    if (sportLower.contains('mma') || sportLower.contains('boxing')) return Icons.sports_mma;
    return Icons.sports;
  }
  
  IconData _getBetTypeIcon(BetType type) {
    switch (type) {
      case BetType.moneyline:
        return Icons.emoji_events;
      case BetType.spread:
        return Icons.trending_up;
      case BetType.total:
        return Icons.add_circle_outline;
      case BetType.prop:
        return Icons.person;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.wasAlreadyPlaced 
            ? AppTheme.neonGreen 
            : widget.isSelected 
              ? widget.color.withOpacity(0.8)
              : (isDarkMode ? Colors.white24 : AppTheme.surfaceBlue.withOpacity(0.3)),
          width: widget.wasAlreadyPlaced || widget.isSelected ? 2.5 : 1,
        ),
        boxShadow: widget.isSelected || widget.wasAlreadyPlaced ? [
          BoxShadow(
            color: (widget.wasAlreadyPlaced ? AppTheme.neonGreen : widget.color).withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ] : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: widget.isSelected || widget.wasAlreadyPlaced ? 4 : 2,
        color: widget.isSelected 
          ? widget.color.withOpacity(0.08)
          : widget.wasAlreadyPlaced 
            ? AppTheme.neonGreen.withOpacity(0.08)
            : (isDarkMode ? Colors.grey[900] : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: widget.wasAlreadyPlaced ? null : widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Team Logo Section
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isSelected || widget.wasAlreadyPlaced
                          ? (widget.wasAlreadyPlaced ? AppTheme.neonGreen : widget.color).withOpacity(0.15)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isSelected || widget.wasAlreadyPlaced
                            ? (widget.wasAlreadyPlaced ? AppTheme.neonGreen : widget.color).withOpacity(0.3)
                            : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: _buildLogoWidget(),
                    ),
                    if (widget.wasAlreadyPlaced || widget.isSelected)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.wasAlreadyPlaced ? AppTheme.neonGreen : widget.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode ? Colors.black : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            widget.wasAlreadyPlaced ? Icons.lock : Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Bet Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: widget.wasAlreadyPlaced 
                            ? AppTheme.neonGreen 
                            : (isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getBetTypeIcon(widget.type),
                            size: 14,
                            color: widget.color.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.wasAlreadyPlaced 
                                  ? AppTheme.neonGreen.withOpacity(0.8)
                                  : (isDarkMode ? Colors.white70 : Colors.black54),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Odds Display with High Contrast
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.wasAlreadyPlaced 
                        ? [AppTheme.neonGreen, AppTheme.neonGreen.withOpacity(0.8)]
                        : widget.isSelected 
                          ? [widget.color, widget.color.withOpacity(0.8)]
                          : isDarkMode
                            ? [Colors.white, Colors.white.withOpacity(0.9)]
                            : [AppTheme.primaryCyan, AppTheme.primaryCyan.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.wasAlreadyPlaced 
                          ? AppTheme.neonGreen.withOpacity(0.4)
                          : widget.isSelected 
                            ? widget.color.withOpacity(0.4)
                            : isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : AppTheme.primaryCyan.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.odds,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.isSelected || widget.wasAlreadyPlaced || !isDarkMode
                        ? Colors.white
                        : AppTheme.deepBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}