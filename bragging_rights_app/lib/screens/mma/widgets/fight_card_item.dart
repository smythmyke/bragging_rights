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
        constraints: BoxConstraints(
          minHeight: fight.isMainEvent || fight.isCoMainEvent ? 155 : 135,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Event badges (Main Event, Co-Main Event)
            if (fight.isMainEvent || fight.isCoMainEvent)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (fight.isMainEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade600, Colors.orange.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'MAIN EVENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (fight.isCoMainEvent && !fight.isMainEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade600, Colors.blue.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'CO-MAIN EVENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Fighters row
            Flexible(
              child: Row(
                children: [
                  // Fighter 1
                  Expanded(
                    child: _buildFighterInfo(
                      fighter: fight.fighter1,
                      isRedCorner: true,
                      alignment: CrossAxisAlignment.center,
                    ),
                  ),

                  // Center Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Weight Class
                        Text(
                          fight.weightClass ?? 'Catchweight',
                          style: TextStyle(
                            color: AppTheme.neonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),

                        // VS Badge
                        Container(
                          padding: const EdgeInsets.all(6),
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
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Rounds
                        Text(
                          '${fight.rounds} RDS',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),

                        // Title Badge
                        if (fight.isTitleFight)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'TITLE FIGHT',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7,
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
                      alignment: CrossAxisAlignment.center,
                    ),
                  ),
                ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.3),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TBA',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final cornerColor = isRedCorner ? Colors.red : Colors.blue;

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFighterAvatar(fighter, cornerColor),
        const SizedBox(height: 4),
        _buildFighterNameAndRecord(fighter, alignment),
      ],
    );
  }

  Widget _buildFighterAvatar(MMAFighter fighter, Color cornerColor) {
    // Use espnId if available, otherwise fallback to id
    final imageId = fighter.espnId ?? fighter.id;

    return FighterImageWidget(
      fighterId: imageId,
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

  Widget _buildFighterNameAndRecord(
    MMAFighter fighter,
    CrossAxisAlignment alignment,
  ) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name - now with more room
        Container(
          width: 85, // Limit width to prevent overflow
          child: Text(
            fighter.displayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: alignment == CrossAxisAlignment.end
                ? TextAlign.right
                : alignment == CrossAxisAlignment.start
                ? TextAlign.left
                : TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        const SizedBox(height: 2),

        // Record
        Text(
          fighter.record.isNotEmpty ? fighter.record : '0-0',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),

        // Ranking & Country in compact form
        if (fighter.ranking != null || fighter.country != null)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              if (fighter.ranking != null)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '#${fighter.ranking}',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (fighter.country != null && fighter.ranking != null)
                SizedBox(width: 3),
              if (fighter.country != null)
                Text(
                  fighter.country!.length > 3
                      ? fighter.country!.substring(0, 3)
                      : fighter.country!,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}