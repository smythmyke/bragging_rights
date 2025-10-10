import 'package:flutter/material.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Injury Intelligence Card
/// Displays injury report with impact levels and status indicators
class InjuryIntelligenceCard extends StatelessWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final bool showFullContent;

  const InjuryIntelligenceCard({
    Key? key,
    required this.cardData,
    required this.onPurchase,
    this.showFullContent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EdgeCardBase(
      cardData: cardData,
      onPurchase: onPurchase,
      showFullContent: showFullContent,
      contentBuilder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, EdgeCardData cardData) {
    // Parse injury data from full content
    final sections = _parseInjuryContent(cardData.fullContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.medical_services,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Injury Report',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Injury count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Text(
                '${cardData.metadata['injuryCount'] ?? 0} players',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // High Impact Injuries
        if (sections['high'] != null && sections['high']!.isNotEmpty) ...[
          _buildImpactSection(
            'HIGH IMPACT',
            sections['high']!,
            Colors.red,
            Icons.error,
          ),
          const SizedBox(height: 12),
        ],

        // Medium Impact Injuries
        if (sections['medium'] != null && sections['medium']!.isNotEmpty) ...[
          _buildImpactSection(
            'MEDIUM IMPACT',
            sections['medium']!,
            Colors.orange,
            Icons.warning,
          ),
          const SizedBox(height: 12),
        ],

        // Low Impact Injuries
        if (sections['low'] != null && sections['low']!.isNotEmpty) ...[
          _buildImpactSection(
            'LOW IMPACT',
            sections['low']!,
            Colors.green,
            Icons.info,
          ),
          const SizedBox(height: 12),
        ],

        // General injury list (if no impact levels specified)
        if (sections['general'] != null && sections['general']!.isNotEmpty) ...[
          _buildGeneralInjuryList(sections['general']!),
          const SizedBox(height: 12),
        ],

        // Impact summary
        if (cardData.impactText != null)
          _buildImpactSummary(cardData.impactText!, cardData.metadata),
      ],
    );
  }

  Map<String, List<String>> _parseInjuryContent(String content) {
    final sections = <String, List<String>>{
      'high': [],
      'medium': [],
      'low': [],
      'general': [],
    };

    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.contains('HIGH IMPACT')) {
        currentSection = 'high';
      } else if (trimmed.contains('MEDIUM IMPACT')) {
        currentSection = 'medium';
      } else if (trimmed.contains('LOW IMPACT')) {
        currentSection = 'low';
      } else if (trimmed.contains('INJURY REPORT')) {
        currentSection = 'general';
      } else if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        final injury = trimmed.replaceFirst(RegExp(r'^[•\-]\s*'), '');
        if (currentSection != null && injury.isNotEmpty) {
          sections[currentSection]!.add(injury);
        }
      }
    }

    return sections;
  }

  Widget _buildImpactSection(
    String title,
    List<String> injuries,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${injuries.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Injury list
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: injuries.asMap().entries.map((entry) {
                final index = entry.key;
                final injury = entry.value;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < injuries.length - 1 ? 8 : 0,
                  ),
                  child: _buildInjuryItem(injury, color),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjuryItem(String injury, Color color) {
    // Try to parse player name and status
    final parts = injury.split(':');
    final playerInfo = parts.isNotEmpty ? parts[0].trim() : injury;
    final details = parts.length > 1 ? parts[1].trim() : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 8),

        // Injury text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerInfo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInjuryList(List<String> injuries) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INJURY REPORT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...injuries.asMap().entries.map((entry) {
            final index = entry.key;
            final injury = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < injuries.length - 1 ? 8 : 0,
              ),
              child: _buildInjuryItem(injury, Colors.white70),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildImpactSummary(String impactText, Map<String, dynamic> metadata) {
    final highImpactCount = metadata['highImpactCount'] ?? 0;
    final totalCount = metadata['injuryCount'] ?? 0;

    Color impactColor;
    IconData impactIcon;

    if (impactText.startsWith('CRITICAL')) {
      impactColor = Colors.red;
      impactIcon = Icons.error;
    } else if (impactText.startsWith('MODERATE')) {
      impactColor = Colors.orange;
      impactIcon = Icons.warning;
    } else {
      impactColor = Colors.blue;
      impactIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: impactColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: impactColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            impactIcon,
            color: impactColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPACT ASSESSMENT',
                  style: TextStyle(
                    color: impactColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  impactText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
