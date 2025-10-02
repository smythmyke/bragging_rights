import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/injury_model.dart';
import '../theme/app_theme.dart';

class InjuryReportWidget extends StatelessWidget {
  final GameInjuryReport report;

  const InjuryReportWidget({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a2a3f), Color(0xFF243447)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                PhosphorIcons.firstAidKit(PhosphorIconsStyle.duotone),
                color: AppTheme.warningAmber,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'INJURY REPORT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Away Team
          _buildTeamInjurySection(
            teamName: report.awayTeamName,
            teamLogo: report.awayTeamLogo,
            injuries: report.awayInjuries,
          ),

          const SizedBox(height: 20),

          Divider(color: Colors.white.withOpacity(0.1)),

          const SizedBox(height: 20),

          // Home Team
          _buildTeamInjurySection(
            teamName: report.homeTeamName,
            teamLogo: report.homeTeamLogo,
            injuries: report.homeInjuries,
          ),

          const SizedBox(height: 20),

          Divider(color: Colors.white.withOpacity(0.1)),

          const SizedBox(height: 20),

          // Intel Insight
          _buildIntelInsight(),
        ],
      ),
    );
  }

  Widget _buildTeamInjurySection({
    required String teamName,
    String? teamLogo,
    required List<Injury> injuries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team Name with Logo
        Row(
          children: [
            if (teamLogo != null) ...[
              CachedNetworkImage(
                imageUrl: teamLogo,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.sports_basketball,
                  size: 32,
                  color: AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                '${teamName.toUpperCase()} INJURY REPORT',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Injury List or "No Injuries"
        if (injuries.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  color: AppTheme.neonGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'No injuries reported',
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...injuries.map((injury) => _buildInjuryItem(injury)),
      ],
    );
  }

  Widget _buildInjuryItem(Injury injury) {
    final statusColor = _getStatusColor(injury.severity);
    final statusIcon = _getStatusIcon(injury.severity);
    final isQuestionable = injury.severity == InjurySeverity.questionable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player Name and Status
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  injury.athleteName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isQuestionable ? AppTheme.warningAmber : statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  injury.status.toUpperCase(),
                  style: TextStyle(
                    color: isQuestionable ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Injury Type
          if (injury.details != null && injury.details!.type != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  PhosphorIcons.firstAid(PhosphorIconsStyle.regular),
                  size: 14,
                  color: const Color(0xFF999999),
                ),
                const SizedBox(width: 6),
                Text(
                  injury.details!.injuryDescription,
                  style: const TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          // Return Date
          if (injury.details?.returnDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  PhosphorIcons.calendarCheck(PhosphorIconsStyle.regular),
                  size: 14,
                  color: const Color(0xFF999999),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatReturnDate(injury.details!.returnDate!),
                  style: const TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          // Comments
          if (injury.shortComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              injury.shortComment,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntelInsight() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningAmber.withOpacity(0.2),
            AppTheme.warningAmber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.lightbulb(PhosphorIconsStyle.duotone),
                color: AppTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'INTEL INSIGHT',
                style: TextStyle(
                  color: AppTheme.warningAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            report.insightText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 10),

          // Impact Scores
          Row(
            children: [
              const Text(
                'Injury Impact Score:',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                'Home: ${report.homeImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  color: report.homeImpactScore > report.awayImpactScore
                      ? AppTheme.errorPink
                      : AppTheme.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                ' | ',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
              ),
              Text(
                'Away: ${report.awayImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  color: report.awayImpactScore > report.homeImpactScore
                      ? AppTheme.errorPink
                      : AppTheme.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(InjurySeverity severity) {
    switch (severity) {
      case InjurySeverity.out:
        return const Color(0xFFFF4444);
      case InjurySeverity.doubtful:
        return const Color(0xFFFF8800);
      case InjurySeverity.questionable:
        return AppTheme.warningAmber;
      case InjurySeverity.dayToDay:
        return AppTheme.primaryCyan;
    }
  }

  IconData _getStatusIcon(InjurySeverity severity) {
    switch (severity) {
      case InjurySeverity.out:
        return PhosphorIcons.x(PhosphorIconsStyle.fill);
      case InjurySeverity.doubtful:
        return PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
      case InjurySeverity.questionable:
        return PhosphorIcons.warning(PhosphorIconsStyle.fill);
      case InjurySeverity.dayToDay:
        return PhosphorIcons.info(PhosphorIconsStyle.fill);
    }
  }

  String _formatReturnDate(DateTime date) {
    if (date.difference(DateTime.now()).inDays < 1) {
      return 'Game-Time Decision';
    }
    return 'Expected Return: ${date.month}/${date.day}/${date.year}';
  }
}
