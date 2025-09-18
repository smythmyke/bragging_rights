import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/mma_fighter_model.dart';
import '../../../theme/app_theme.dart';

class TaleOfTapeWidget extends StatelessWidget {
  final MMAFighter fighter1;
  final MMAFighter fighter2;
  final String? weightClass;
  final int rounds;
  final bool isTitle;
  final bool showExtended;

  const TaleOfTapeWidget({
    Key? key,
    required this.fighter1,
    required this.fighter2,
    this.weightClass,
    this.rounds = 3,
    this.isTitle = false,
    this.showExtended = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fighters Section
        Row(
          children: [
            // Fighter 1 (Red Corner)
            Expanded(
              child: _buildFighterSection(
                fighter: fighter1,
                isRedCorner: true,
              ),
            ),

            // VS Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.neonGreen.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.neonGreen,
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (weightClass != null)
                    Text(
                      weightClass!,
                      style: TextStyle(
                        color: AppTheme.neonGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    '$rounds Rounds',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (isTitle)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Fighter 2 (Blue Corner)
            Expanded(
              child: _buildFighterSection(
                fighter: fighter2,
                isRedCorner: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Stats Comparison
        _buildStatsComparison(),

        if (showExtended) ...[
          const SizedBox(height: 24),
          _buildExtendedStats(),
        ],
      ],
    );
  }

  Widget _buildFighterSection({
    required MMAFighter fighter,
    required bool isRedCorner,
  }) {
    final cornerColor = isRedCorner ? Colors.red : Colors.blue;

    return Column(
      children: [
        // Fighter Image
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cornerColor,
              width: 3,
            ),
            gradient: RadialGradient(
              colors: [
                cornerColor.withOpacity(0.2),
                cornerColor.withOpacity(0.05),
              ],
            ),
          ),
          child: ClipOval(
            child: fighter.headshotUrl != null
                ? CachedNetworkImage(
                    imageUrl: fighter.headshotUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cornerColor,
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildFighterInitials(fighter),
                  )
                : _buildFighterInitials(fighter),
          ),
        ),

        const SizedBox(height: 12),

        // Fighter Name
        Text(
          fighter.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        // Nickname
        if (fighter.nickname != null)
          Text(
            '"${fighter.nickname}"',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

        const SizedBox(height: 8),

        // Record
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cornerColor.withOpacity(0.5),
            ),
          ),
          child: Text(
            fighter.record,
            style: TextStyle(
              color: cornerColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Country Flag
        if (fighter.flagUrl != null || fighter.country != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fighter.flagUrl != null)
                CachedNetworkImage(
                  imageUrl: fighter.flagUrl!,
                  width: 24,
                  height: 16,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              if (fighter.country != null) ...[
                const SizedBox(width: 4),
                Text(
                  fighter.country!,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

        const SizedBox(height: 8),

        // Recent Form
        if (fighter.recentForm != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: fighter.recentForm!.take(5).map((result) {
              Color color;
              switch (result) {
                case 'W':
                  color = Colors.green;
                  break;
                case 'L':
                  color = Colors.red;
                  break;
                case 'D':
                case 'NC':
                  color = Colors.grey;
                  break;
                default:
                  color = Colors.grey;
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color),
                ),
                child: Center(
                  child: Text(
                    result,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFighterInitials(MMAFighter fighter) {
    final names = fighter.name.split(' ');
    final initials = names.length >= 2
        ? '${names.first[0]}${names.last[0]}'
        : fighter.name.substring(0, 2);

    return Container(
      color: AppTheme.surfaceBlue,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.neonGreen,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsComparison() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _buildStatRow(
            label: 'Age',
            value1: fighter1.age?.toString() ?? 'N/A',
            value2: fighter2.age?.toString() ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            label: 'Height',
            value1: fighter1.displayHeight ?? fighter1.heightFeetInches,
            value2: fighter2.displayHeight ?? fighter2.heightFeetInches,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            label: 'Weight',
            value1: fighter1.displayWeight ?? '${fighter1.weight ?? 'N/A'} lbs',
            value2: fighter2.displayWeight ?? '${fighter2.weight ?? 'N/A'} lbs',
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            label: 'Reach',
            value1: fighter1.displayReach ?? fighter1.reachInches,
            value2: fighter2.displayReach ?? fighter2.reachInches,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            label: 'Stance',
            value1: fighter1.stance ?? 'N/A',
            value2: fighter2.stance ?? 'N/A',
          ),
          if (fighter1.camp != null || fighter2.camp != null) ...[
            const SizedBox(height: 12),
            _buildStatRow(
              label: 'Camp',
              value1: fighter1.camp ?? 'N/A',
              value2: fighter2.camp ?? 'N/A',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String label,
    required String value1,
    required String value2,
  }) {
    // Determine which fighter has the advantage
    bool? fighter1Advantage;
    if (label == 'Reach' || label == 'Height') {
      double? val1 = _parseNumericValue(value1);
      double? val2 = _parseNumericValue(value2);
      if (val1 != null && val2 != null) {
        fighter1Advantage = val1 > val2 ? true : (val1 < val2 ? false : null);
      }
    }

    return Row(
      children: [
        // Fighter 1 Value
        Expanded(
          child: Text(
            value1,
            style: TextStyle(
              color: fighter1Advantage == true
                  ? AppTheme.neonGreen
                  : Colors.white,
              fontSize: 14,
              fontWeight: fighter1Advantage == true
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Label
        Container(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Fighter 2 Value
        Expanded(
          child: Text(
            value2,
            style: TextStyle(
              color: fighter1Advantage == false
                  ? AppTheme.neonGreen
                  : Colors.white,
              fontSize: 14,
              fontWeight: fighter1Advantage == false
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildExtendedStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WIN METHODS',
            style: TextStyle(
              color: AppTheme.neonGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // KO/TKO
          _buildWinMethodRow(
            label: 'KO/TKO',
            value1: fighter1.knockouts ?? 0,
            value2: fighter2.knockouts ?? 0,
            total1: fighter1.wins ?? 0,
            total2: fighter2.wins ?? 0,
          ),
          const SizedBox(height: 8),

          // Submissions
          _buildWinMethodRow(
            label: 'Submission',
            value1: fighter1.submissions ?? 0,
            value2: fighter2.submissions ?? 0,
            total1: fighter1.wins ?? 0,
            total2: fighter2.wins ?? 0,
          ),
          const SizedBox(height: 8),

          // Decisions
          _buildWinMethodRow(
            label: 'Decision',
            value1: fighter1.decisions ?? 0,
            value2: fighter2.decisions ?? 0,
            total1: fighter1.wins ?? 0,
            total2: fighter2.wins ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildWinMethodRow({
    required String label,
    required int value1,
    required int value2,
    required int total1,
    required int total2,
  }) {
    final percentage1 = total1 > 0 ? (value1 / total1 * 100) : 0.0;
    final percentage2 = total2 > 0 ? (value2 / total2 * 100) : 0.0;

    return Column(
      children: [
        Row(
          children: [
            // Fighter 1
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value1',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${percentage1.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Label
            Container(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Fighter 2
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value2',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${percentage2.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Visual Bar
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: percentage1 / 100,
                backgroundColor: Colors.red.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 80),
            Expanded(
              child: Transform.scale(
                scaleX: -1,
                child: LinearProgressIndicator(
                  value: percentage2 / 100,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double? _parseNumericValue(String value) {
    // Extract numeric value from strings like "72\"" or "5'11\""
    final regex = RegExp(r'[\d.]+');
    final matches = regex.allMatches(value);

    if (matches.isNotEmpty) {
      final firstMatch = matches.first.group(0);
      if (firstMatch != null) {
        return double.tryParse(firstMatch);
      }
    }

    return null;
  }
}