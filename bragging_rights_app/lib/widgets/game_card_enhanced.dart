import 'package:flutter/material.dart';
import '../models/enhanced_game_model.dart';
import '../models/participant_model.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Enhanced Game Card widget that properly displays teams vs individuals
class GameCardEnhanced extends StatelessWidget {
  final EnhancedGameModel game;
  final VoidCallback? onTap;
  final bool showOdds;
  final bool compact;

  const GameCardEnhanced({
    Key? key,
    required this.game,
    this.onTap,
    this.showOdds = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildFullCard(BuildContext context) {
    final theme = Theme.of(context);
    final isIndividual = game.homeParticipant.isIndividualSport;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: game.isLive 
          ? BorderSide(color: theme.colorScheme.error, width: 2)
          : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildParticipants(context),
              if (game.isLive || game.isFinal) ...[
                const SizedBox(height: 8),
                _buildScore(context),
              ],
              if (showOdds && game.canShowOdds) ...[
                const SizedBox(height: 12),
                _buildOdds(context),
              ],
              const SizedBox(height: 8),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCompactParticipants(context),
              const Spacer(),
              if (game.isLive || game.isFinal)
                _buildCompactScore(context)
              else
                _buildCompactTime(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // Sport badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getSportColor(game.sport).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getSportColor(game.sport)),
          ),
          child: Text(
            game.sport.toUpperCase(),
            style: TextStyle(
              color: _getSportColor(game.sport),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // Competition info
        if (game.competitionDisplay != null) ...[
          Expanded(
            child: Text(
              game.competitionDisplay!,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        
        // Status badge
        if (game.isLive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParticipants(BuildContext context) {
    final theme = Theme.of(context);
    final isIndividual = game.homeParticipant.isIndividualSport;
    
    return Column(
      children: [
        // Away/Player 1
        _buildParticipantRow(
          context,
          game.awayParticipant,
          isHome: false,
          isIndividual: isIndividual,
        ),
        
        // Versus indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  game.versusText,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        
        // Home/Player 2
        _buildParticipantRow(
          context,
          game.homeParticipant,
          isHome: true,
          isIndividual: isIndividual,
        ),
      ],
    );
  }

  Widget _buildParticipantRow(
    BuildContext context,
    Participant participant,
    {required bool isHome, required bool isIndividual}
  ) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // Logo/Avatar
        if (participant.logo != null) ...[
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(participant.logo!),
            backgroundColor: theme.colorScheme.surface,
          ),
        ] else ...[
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Text(
              participant.shortName.substring(0, 1),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        
        // Name and details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ranking/Seed for individuals
                  if (isIndividual && participant.ranking != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${participant.ranking}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Name
                  Expanded(
                    child: Text(
                      participant.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Country flag for individuals
                  if (isIndividual && participant.country != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      participant.country!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              
              // Additional info
              if (!isIndividual && participant.conference != null) ...[
                Text(
                  participant.conference!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Home/Away indicator for teams
        if (!isIndividual) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHome 
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isHome ? 'HOME' : 'AWAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isHome 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScore(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            game.formattedScore,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (game.periodDisplay != null) ...[
            const SizedBox(width: 16),
            Text(
              game.periodDisplay!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (game.timeRemaining != null) ...[
            const SizedBox(width: 8),
            Text(
              game.timeRemaining!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOdds(BuildContext context) {
    final theme = Theme.of(context);
    final primaryOdds = game.primaryOdds;
    
    if (primaryOdds == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.casino_outlined,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            primaryOdds,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        // Game time
        if (game.isScheduled) ...[
          Icon(
            Icons.schedule,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 4),
          Text(
            _formatGameTime(game.gameTime),
            style: theme.textTheme.bodySmall,
          ),
        ],
        
        const Spacer(),
        
        // Venue
        if (game.venueDisplay != null) ...[
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              game.venueDisplay!,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactParticipants(BuildContext context) {
    return Expanded(
      child: Text(
        game.shortTitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCompactScore(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: game.isLive 
          ? theme.colorScheme.error.withOpacity(0.1)
          : theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        game.formattedScore,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: game.isLive 
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildCompactTime(BuildContext context) {
    return Text(
      _formatGameTime(game.gameTime),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Color _getSportColor(String sport) {
    switch (sport.toLowerCase()) {
      case 'nba':
        return AppTheme.warningAmber;
      case 'nfl':
        return Colors.brown;
      case 'nhl':
        return AppTheme.primaryCyan;
      case 'mlb':
        return Colors.indigo;
      case 'tennis':
        return AppTheme.neonGreen;
      case 'mma':
      case 'ufc':
        return AppTheme.errorPink;
      case 'boxing':
        return AppTheme.warningAmber;
      case 'soccer':
        return Colors.purple;
      case 'golf':
        return Colors.teal;
      default:
        return AppTheme.surfaceBlue;
    }
  }

  String _formatGameTime(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now);
    
    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(time);
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} min';
    } else {
      return DateFormat('h:mm a').format(time);
    }
  }
}