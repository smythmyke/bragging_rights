import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/mma_event_model.dart';
import '../../../models/mma_fighter_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/fighter_image_widget.dart';

class FightCardItem extends StatelessWidget {
  final MMAFight fight;
  final VoidCallback? onTap;

  const FightCardItem({
    Key? key,
    required this.fight,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Fighter 1
            Expanded(
              child: _buildFighterInfo(
                fighter: fight.fighter1,
                isRedCorner: true,
                alignment: CrossAxisAlignment.start,
              ),
            ),

            // Center Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  // Weight Class
                  Text(
                    fight.weightClass ?? 'Catchweight',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // VS Badge
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceBlue,
                      border: Border.all(
                        color: AppTheme.borderCyan.withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Rounds
                  Text(
                    '${fight.rounds} RDS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),

                  // Title Badge
                  if (fight.isTitleFight)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TITLE',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Fighter 2
            Expanded(
              child: _buildFighterInfo(
                fighter: fight.fighter2,
                isRedCorner: false,
                alignment: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFighterInfo({
    MMAFighter? fighter,
    required bool isRedCorner,
    required CrossAxisAlignment alignment,
  }) {
    if (fighter == null) {
      return Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            'TBA',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final cornerColor = isRedCorner ? Colors.red : Colors.blue;

    return Row(
      mainAxisAlignment:
          isRedCorner ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: isRedCorner
          ? [
              _buildFighterAvatar(fighter, cornerColor),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFighterDetails(fighter, alignment),
              ),
            ]
          : [
              Expanded(
                child: _buildFighterDetails(fighter, alignment),
              ),
              const SizedBox(width: 12),
              _buildFighterAvatar(fighter, cornerColor),
            ],
    );
  }

  Widget _buildFighterAvatar(MMAFighter fighter, Color cornerColor) {
    return FighterImageWidget(
      fighterId: fighter.id,
      fallbackUrl: fighter.headshotUrl,
      size: 48,
      shape: BoxShape.circle,
      borderColor: cornerColor.withOpacity(0.6),
      borderWidth: 2,
      placeholder: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cornerColor,
        ),
      ),
      errorWidget: _buildInitials(fighter),
    );
  }

  Widget _buildInitials(MMAFighter fighter) {
    final names = fighter.name.split(' ');
    final initials = names.length >= 2
        ? '${names.first[0]}${names.last[0]}'
        : fighter.name.substring(0, 2);

    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFighterDetails(
    MMAFighter fighter,
    CrossAxisAlignment alignment,
  ) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Name with responsive sizing
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate font size based on name length and available width
            final nameLength = fighter.displayName.length;
            double fontSize = 14;

            if (nameLength > 20) {
              fontSize = 11;
            } else if (nameLength > 15) {
              fontSize = 12;
            } else if (nameLength > 12) {
              fontSize = 13;
            }

            return Text(
              fighter.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1.1, // Tighter line height
              ),
              textAlign: alignment == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            );
          },
        ),
        const SizedBox(height: 2),

        // Record
        Text(
          fighter.record,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),

        // Country & Ranking
        if (fighter.country != null || fighter.ranking != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fighter.ranking != null)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${fighter.ranking}',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (fighter.country != null)
                Text(
                  fighter.country!,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}