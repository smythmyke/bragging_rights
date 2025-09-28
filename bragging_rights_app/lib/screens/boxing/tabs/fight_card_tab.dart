import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/boxing_fight_model.dart';
import '../../../theme/app_theme.dart';

class FightCardTab extends StatelessWidget {
  final List<BoxingFight>? fights;
  final bool isLoading;

  const FightCardTab({
    Key? key,
    required this.fights,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.neonGreen,
        ),
      );
    }

    if (fights == null || fights!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.boxingGlove(PhosphorIconsStyle.light),
              size: 64,
              color: AppTheme.surfaceBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'Fight card not available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back closer to the event',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      itemCount: fights!.length,
      itemBuilder: (context, index) {
        final fight = fights![index];
        // First fight in the list is the main event
        final isMainEventPosition = index == 0;
        return _FightCard(
          fight: fight,
          isMainEventPosition: isMainEventPosition,
        );
      },
    );
  }
}

class _FightCard extends StatelessWidget {
  final BoxingFight fight;
  final bool isMainEventPosition;

  const _FightCard({
    required this.fight,
    this.isMainEventPosition = false,
  });

  @override
  Widget build(BuildContext context) {
    // Highlight main event with special styling
    final isMainEvent = fight.isMainEvent || isMainEventPosition;

    return Card(
      color: isMainEvent
          ? AppTheme.surfaceBlue
          : AppTheme.surfaceBlue,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isMainEvent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMainEvent
            ? const BorderSide(color: AppTheme.neonGreen, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fight header with badges
            Row(
              children: [
                if (isMainEvent) ...[
                  _Badge(
                    label: 'MAIN EVENT',
                    color: AppTheme.neonGreen,
                    icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
                  ),
                  const SizedBox(width: 8),
                ],
                if (fight.isTitleFight && !isMainEvent) ...[
                  _Badge(
                    label: 'TITLE FIGHT',
                    color: AppTheme.warningAmber,
                    icon: PhosphorIcons.crown(PhosphorIconsStyle.fill),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    '${fight.scheduledRounds} ROUNDS',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Add MAIN EVENT label for first fight
            if (isMainEvent)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'MAIN EVENT',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

            // Fighters with images
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Fighter 1 image
                      if (fight.fighters['fighter1']!.imageUrl != null)
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(
                            fight.fighters['fighter1']!.imageUrl!,
                          ),
                          backgroundColor: AppTheme.cardBlue,
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.cardBlue,
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      const SizedBox(height: 8),
                      _FighterInfo(
                        fighter: fight.fighters['fighter1']!,
                        alignment: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      // Fighter 2 image
                      if (fight.fighters['fighter2']!.imageUrl != null)
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(
                            fight.fighters['fighter2']!.imageUrl!,
                          ),
                          backgroundColor: AppTheme.cardBlue,
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.cardBlue,
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      const SizedBox(height: 8),
                      _FighterInfo(
                        fighter: fight.fighters['fighter2']!,
                        alignment: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Division and titles
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.scales(PhosphorIconsStyle.regular),
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fight.division.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (fight.titles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...fight.titles.map((title) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.warningAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FighterInfo extends StatelessWidget {
  final BoxingFighterInfo fighter;
  final TextAlign alignment;

  const _FighterInfo({
    required this.fighter,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final crossAlign = alignment == TextAlign.left
        ? CrossAxisAlignment.start
        : alignment == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center;

    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          fighter.fullName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: alignment,
        ),
        if (fighter.record != null) ...[
          const SizedBox(height: 4),
          Text(
            fighter.record!,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: alignment,
          ),
        ],
        if (fighter.nationality != null) ...[
          const SizedBox(height: 2),
          Text(
            fighter.nationality!,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.5),
              fontSize: 12,
            ),
            textAlign: alignment,
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}