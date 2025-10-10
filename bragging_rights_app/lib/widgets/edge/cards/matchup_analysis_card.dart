import 'package:flutter/material.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Matchup Analysis Card
/// Displays team statistics, recent form, and matchup insights
class MatchupAnalysisCard extends StatelessWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final bool showFullContent;

  const MatchupAnalysisCard({
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
    final sections = _parseMatchupContent(cardData.fullContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.compare_arrows,
              color: Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Matchup Intelligence',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Team Statistics
        if (sections['offensive'] != null && sections['offensive']!.isNotEmpty) ...[
          _buildStatsSection(
            'OFFENSIVE ANALYSIS',
            sections['offensive']!,
            Icons.sports_score,
            Colors.green,
          ),
          const SizedBox(height: 12),
        ],

        if (sections['defensive'] != null && sections['defensive']!.isNotEmpty) ...[
          _buildStatsSection(
            'DEFENSIVE ANALYSIS',
            sections['defensive']!,
            Icons.shield,
            Colors.blue,
          ),
          const SizedBox(height: 12),
        ],

        // Recent Form
        if (sections['form'] != null && sections['form']!.isNotEmpty) ...[
          _buildFormSection(sections['form']!),
          const SizedBox(height: 12),
        ],

        // Key Matchups
        if (sections['matchups'] != null && sections['matchups']!.isNotEmpty)
          _buildKeyMatchups(sections['matchups']!),
      ],
    );
  }

  Map<String, List<String>> _parseMatchupContent(String content) {
    final sections = <String, List<String>>{
      'offensive': [],
      'defensive': [],
      'form': [],
      'matchups': [],
    };

    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.contains('OFFENSIVE ANALYSIS')) {
        currentSection = 'offensive';
      } else if (trimmed.contains('DEFENSIVE ANALYSIS')) {
        currentSection = 'defensive';
      } else if (trimmed.contains('RECENT FORM')) {
        currentSection = 'form';
      } else if (trimmed.contains('KEY MATCHUPS')) {
        currentSection = 'matchups';
      } else if (trimmed.startsWith('•')) {
        final text = trimmed.replaceFirst('•', '').trim();
        if (currentSection != null && text.isNotEmpty) {
          sections[currentSection]!.add(text);
        }
      }
    }

    return sections;
  }

  Widget _buildStatsSection(
    String title,
    List<String> stats,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
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
            ],
          ),
          const SizedBox(height: 12),
          ...stats.map((stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stat,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFormSection(List<String> formStats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                'RECENT FORM',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...formStats.map((stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stat,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKeyMatchups(List<String> matchups) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.contrast, color: Colors.purple, size: 16),
              SizedBox(width: 8),
              Text(
                'KEY MATCHUPS',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...matchups.asMap().entries.map((entry) {
            final index = entry.key;
            final matchup = entry.value;

            return Container(
              margin: EdgeInsets.only(
                bottom: index < matchups.length - 1 ? 8 : 0,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.stars,
                      color: Colors.purple,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      matchup,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
