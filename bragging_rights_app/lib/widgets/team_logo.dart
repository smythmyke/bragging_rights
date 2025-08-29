import 'package:flutter/material.dart';
import '../services/team_logo_service.dart';

/// Widget to display team logos with automatic caching
class TeamLogo extends StatefulWidget {
  final String sport;
  final String teamId;
  final String teamName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showPlaceholder;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const TeamLogo({
    Key? key,
    required this.sport,
    required this.teamId,
    required this.teamName,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.contain,
    this.showPlaceholder = true,
    this.borderRadius,
    this.boxShadow,
  }) : super(key: key);

  @override
  State<TeamLogo> createState() => _TeamLogoState();
}

class _TeamLogoState extends State<TeamLogo> {
  final TeamLogoService _logoService = TeamLogoService();
  Future<Widget>? _logoFuture;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  @override
  void didUpdateWidget(TeamLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || 
        oldWidget.sport != widget.sport) {
      _loadLogo();
    }
  }

  void _loadLogo() {
    _logoFuture = _logoService.getTeamLogoWidget(
      sport: widget.sport,
      teamId: widget.teamId,
      teamName: widget.teamName,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        boxShadow: widget.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        child: FutureBuilder<Widget>(
          future: _logoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingWidget();
            }
            
            if (snapshot.hasData) {
              return snapshot.data!;
            }
            
            if (widget.showPlaceholder) {
              return _buildPlaceholderWidget();
            }
            
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: (widget.width ?? 50) * 0.4,
          height: (widget.height ?? 50) * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          _getSportIcon(),
          color: Colors.grey[600],
          size: (widget.width ?? 50) * 0.5,
        ),
      ),
    );
  }

  IconData _getSportIcon() {
    switch (widget.sport.toLowerCase()) {
      case 'nba':
        return Icons.sports_basketball;
      case 'nfl':
        return Icons.sports_football;
      case 'mlb':
        return Icons.sports_baseball;
      case 'nhl':
        return Icons.sports_hockey;
      default:
        return Icons.sports;
    }
  }
}

/// Compact team logo for lists
class TeamLogoCompact extends StatelessWidget {
  final String sport;
  final String teamId;
  final String teamName;
  final double size;

  const TeamLogoCompact({
    Key? key,
    required this.sport,
    required this.teamId,
    required this.teamName,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      sport: sport,
      teamId: teamId,
      teamName: teamName,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }
}

/// Large team logo for headers
class TeamLogoLarge extends StatelessWidget {
  final String sport;
  final String teamId;
  final String teamName;
  final double? width;
  final double? height;
  final bool showGradient;

  const TeamLogoLarge({
    Key? key,
    required this.sport,
    required this.teamId,
    required this.teamName,
    this.width = 120,
    this.height = 120,
    this.showGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget logo = TeamLogo(
      sport: sport,
      teamId: teamId,
      teamName: teamName,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (showGradient) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: (width ?? 120) + 10,
            height: (height ?? 120) + 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.3),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ],
              ),
            ),
          ),
          logo,
        ],
      );
    }

    return logo;
  }
}

/// Team vs Team logo display
class TeamVersusLogos extends StatelessWidget {
  final String sport;
  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final double logoSize;

  const TeamVersusLogos({
    Key? key,
    required this.sport,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    this.logoSize = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Home team
        TeamLogo(
          sport: sport,
          teamId: homeTeamId,
          teamName: homeTeamName,
          width: logoSize,
          height: logoSize,
        ),
        
        // VS divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VS',
                style: TextStyle(
                  fontSize: logoSize * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Away team
        TeamLogo(
          sport: sport,
          teamId: awayTeamId,
          teamName: awayTeamName,
          width: logoSize,
          height: logoSize,
        ),
      ],
    );
  }
}