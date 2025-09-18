import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/boxing_fight_model.dart';
import '../../../models/boxing_fighter_model.dart';
import '../../../services/boxing_service.dart';
import '../../../theme/app_theme.dart';

class FightersTab extends StatefulWidget {
  final List<BoxingFight>? fights;
  final BoxingService boxingService;

  const FightersTab({
    Key? key,
    required this.fights,
    required this.boxingService,
  }) : super(key: key);

  @override
  State<FightersTab> createState() => _FightersTabState();
}

class _FightersTabState extends State<FightersTab> {
  final Map<String, BoxingFighter> _fighterCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFighters();
  }

  Future<void> _loadFighters() async {
    if (widget.fights == null || widget.fights!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Extract unique fighter IDs
    final fighterIds = <String>{};
    for (var fight in widget.fights!) {
      fighterIds.add(fight.fighters['fighter1']!.id);
      fighterIds.add(fight.fighters['fighter2']!.id);
    }

    // Load fighter details
    for (var id in fighterIds) {
      final fighter = await widget.boxingService.getFighter(id);
      if (fighter != null) {
        _fighterCache[id] = fighter;
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.neonGreen,
        ),
      );
    }

    if (widget.fights == null || widget.fights!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.users(PhosphorIconsStyle.light),
              size: 64,
              color: AppTheme.surfaceBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'No fighter information available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.fights!.length,
      itemBuilder: (context, index) {
        final fight = widget.fights![index];
        final fighter1 = _fighterCache[fight.fighters['fighter1']!.id];
        final fighter2 = _fighterCache[fight.fighters['fighter2']!.id];

        return _TaleOfTheTape(
          fight: fight,
          fighter1: fighter1,
          fighter2: fighter2,
        );
      },
    );
  }
}

class _TaleOfTheTape extends StatelessWidget {
  final BoxingFight fight;
  final BoxingFighter? fighter1;
  final BoxingFighter? fighter2;

  const _TaleOfTheTape({
    required this.fight,
    this.fighter1,
    this.fighter2,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceBlue,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Fight title
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (fight.isMainEvent)
                    Icon(
                      PhosphorIcons.star(PhosphorIconsStyle.fill),
                      size: 16,
                      color: AppTheme.neonGreen,
                    )
                  else if (fight.isTitleFight)
                    Icon(
                      PhosphorIcons.crown(PhosphorIconsStyle.fill),
                      size: 16,
                      color: AppTheme.warningAmber,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      fight.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tale of the tape
            Row(
              children: [
                // Fighter 1
                Expanded(
                  child: _FighterColumn(
                    fighterInfo: fight.fighters['fighter1']!,
                    fighter: fighter1,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),

                // VS divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.neonGreen,
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: AppTheme.neonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fighter 2
                Expanded(
                  child: _FighterColumn(
                    fighterInfo: fight.fighters['fighter2']!,
                    fighter: fighter2,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
              ],
            ),

            if (fighter1 != null && fighter2 != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.grey, height: 1),
              const SizedBox(height: 16),

              // Stats comparison
              _StatComparison(
                label: 'HEIGHT',
                value1: fighter1?.physical.height ?? '',
                value2: fighter2?.physical.height ?? '',
              ),
              const SizedBox(height: 12),
              _StatComparison(
                label: 'REACH',
                value1: fighter1?.physical.reach ?? '',
                value2: fighter2?.physical.reach ?? '',
              ),
              const SizedBox(height: 12),
              _StatComparison(
                label: 'STANCE',
                value1: fighter1?.physical.stance ?? '',
                value2: fighter2?.physical.stance ?? '',
              ),
              const SizedBox(height: 12),
              _StatComparison(
                label: 'KO %',
                value1: '${fighter1?.koPercentage.toStringAsFixed(0) ?? '0'}%',
                value2: '${fighter2?.koPercentage.toStringAsFixed(0) ?? '0'}%',
                isPercentage: true,
                percentage1: fighter1?.koPercentage ?? 0,
                percentage2: fighter2?.koPercentage ?? 0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FighterColumn extends StatelessWidget {
  final BoxingFighterInfo fighterInfo;
  final BoxingFighter? fighter;
  final CrossAxisAlignment alignment;

  const _FighterColumn({
    required this.fighterInfo,
    this.fighter,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          fighterInfo.fullName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          fighter?.record ?? fighterInfo.record ?? '--',
          style: TextStyle(
            color: AppTheme.neonGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fighterInfo.nationality ?? fighter?.nationality ?? '',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        if (fighter != null) ...[
          const SizedBox(height: 4),
          Text(
            fighter!.division ?? '',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatComparison extends StatelessWidget {
  final String label;
  final String value1;
  final String value2;
  final bool isPercentage;
  final double? percentage1;
  final double? percentage2;

  const _StatComparison({
    required this.label,
    required this.value1,
    required this.value2,
    this.isPercentage = false,
    this.percentage1,
    this.percentage2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isPercentage && percentage1 != null && percentage2 != null
                  ? (percentage1! > percentage2! ? FontWeight.bold : FontWeight.normal)
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value2,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isPercentage && percentage1 != null && percentage2 != null
                  ? (percentage2! > percentage1! ? FontWeight.bold : FontWeight.normal)
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }
}