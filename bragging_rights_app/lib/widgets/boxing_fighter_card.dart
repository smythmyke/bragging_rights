import 'package:flutter/material.dart';
import '../models/boxing_fight_model.dart';
import '../theme/app_theme.dart';
import 'fighter_image_widget.dart';

/// Boxing fighter card with graceful degradation
/// Shows enriched data from Boxing Data API cache when available
/// Hides fields when data is missing (no empty placeholders)
class BoxingFighterCard extends StatelessWidget {
  final BoxingFighterInfo fighter;
  final bool isCompact;
  final VoidCallback? onTap;

  const BoxingFighterCard({
    Key? key,
    required this.fighter,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderGray,
            width: 1,
          ),
        ),
        child: isCompact ? _buildCompactLayout() : _buildFullLayout(),
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Row(
      children: [
        // Fighter image with graceful fallback
        FighterImageWidget(
          fighterId: fighter.id,
          directUrl: fighter.imageUrl,  // Use cached image if available
          size: 40,
          shape: BoxShape.circle,
          borderColor: fighter.isChampion == true ? Colors.amber : null,
          errorWidget: FighterInitialsWidget(
            name: fighter.name,
            size: 40,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Champion icon if applicable
                  if (fighter.isChampion == true) ...[
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Fighter name (always shown - from Odds API)
                  Expanded(
                    child: Text(
                      fighter.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Ranking if available
                  if (fighter.ranking != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      fighter.ranking!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neonGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              // Record if available (e.g., "32-2-1")
              if (fighter.record != null && fighter.record!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  fighter.record!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullLayout() {
    return Column(
      children: [
        // Fighter image
        FighterImageWidget(
          fighterId: fighter.id,
          directUrl: fighter.imageUrl,  // Use cached image if available
          size: 80,
          shape: BoxShape.circle,
          borderColor: fighter.isChampion == true ? Colors.amber : AppTheme.borderGray,
          borderWidth: fighter.isChampion == true ? 3 : 2,
          errorWidget: FighterInitialsWidget(
            name: fighter.name,
            size: 80,
          ),
        ),
        const SizedBox(height: 8),

        // Champion badge if applicable
        if (fighter.isChampion == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, size: 12, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  'CHAMPION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Fighter name (always shown)
        Text(
          fighter.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Ranking if available
        if (fighter.ranking != null) ...[
          const SizedBox(height: 2),
          Text(
            fighter.ranking!,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neonGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],

        // Record if available
        if (fighter.record != null && fighter.record!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              fighter.record!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],

        // Nationality if available
        if (fighter.nationality != null && fighter.nationality!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            fighter.nationality!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// Boxing fight card showing both fighters
class BoxingFightCard extends StatelessWidget {
  final BoxingFight fight;
  final VoidCallback? onTap;
  final bool showOdds;

  const BoxingFightCard({
    Key? key,
    required this.fight,
    this.onTap,
    this.showOdds = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fighter1 = fight.fighters['fighter1']!;
    final fighter2 = fight.fighters['fighter2']!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fight.isMainEvent ? AppTheme.neonGreen : AppTheme.borderGray,
            width: fight.isMainEvent ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Title badges
            if (fight.isTitleFight) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fight.titles.join(' • '),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Fighters row
            Row(
              children: [
                // Fighter 1
                Expanded(
                  child: BoxingFighterCard(
                    fighter: fighter1,
                    isCompact: false,
                  ),
                ),

                // VS divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      if (fight.scheduledRounds > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${fight.scheduledRounds}R',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Fighter 2
                Expanded(
                  child: BoxingFighterCard(
                    fighter: fighter2,
                    isCompact: false,
                  ),
                ),
              ],
            ),

            // Division and odds
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Division (if available)
                if (fight.division.isNotEmpty && fight.division != 'TBD') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fight.division.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],

                // Odds if available and requested
                if (showOdds && fight.odds != null) ...[
                  if (fight.division.isNotEmpty && fight.division != 'TBD')
                    const SizedBox(width: 8),
                  Row(
                    children: [
                      _buildOdds(fighter1.name, fight.odds!['fighter1_odds']),
                      const SizedBox(width: 8),
                      _buildOdds(fighter2.name, fight.odds!['fighter2_odds']),
                    ],
                  ),
                ],
              ],
            ),

            // Main Event badge
            if (fight.isMainEvent) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.neonGreen.withOpacity(0.3), AppTheme.neonGreen.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.neonGreen, width: 1),
                ),
                child: const Text(
                  'MAIN EVENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.neonGreen,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOdds(String name, dynamic odds) {
    if (odds == null) return const SizedBox.shrink();

    final oddsValue = odds is num ? odds.toDouble() : 0.0;
    final oddsString = oddsValue > 0 ? '+${oddsValue.toStringAsFixed(0)}' : oddsValue.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.neonGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        oddsString,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.neonGreen,
        ),
      ),
    );
  }
}