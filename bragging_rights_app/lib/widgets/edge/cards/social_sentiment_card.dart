import 'package:flutter/material.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Social Sentiment Card
/// Displays fan confidence, community sentiment, and contrarian opportunities
class SocialSentimentCard extends StatelessWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final bool showFullContent;

  const SocialSentimentCard({
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
    final sections = _parseSocialContent(cardData.fullContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.people,
              color: Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fan Sentiment',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.trending_up, size: 12, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'TRENDING',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Confidence bars
        if (sections['confidence'] != null && sections['confidence']!.isNotEmpty) ...[
          _buildConfidenceBars(sections['confidence']!),
          const SizedBox(height: 16),
        ],

        // Community insights
        if (sections['insights'] != null && sections['insights']!.isNotEmpty) ...[
          _buildCommunityInsights(sections['insights']!),
          const SizedBox(height: 12),
        ],

        // Contrarian alert
        if (sections['contrarian'] != null && sections['contrarian']!.isNotEmpty)
          _buildContrarianAlert(sections['contrarian']!),
      ],
    );
  }

  Map<String, List<String>> _parseSocialContent(String content) {
    final sections = <String, List<String>>{
      'confidence': [],
      'insights': [],
      'contrarian': [],
    };

    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.contains('FAN SENTIMENT')) {
        currentSection = 'confidence';
      } else if (trimmed.contains('COMMUNITY INSIGHTS')) {
        currentSection = 'insights';
      } else if (trimmed.contains('CONTRARIAN OPPORTUNITY')) {
        currentSection = 'contrarian';
      } else if (trimmed.contains(':') && currentSection == 'confidence') {
        // Confidence line format: "Team: XX% confident"
        sections['confidence']!.add(trimmed);
      } else if (trimmed.startsWith('•')) {
        final text = trimmed.replaceFirst('•', '').trim();
        if (currentSection != null && text.isNotEmpty) {
          sections[currentSection]!.add(text);
        }
      } else if (currentSection == 'contrarian' && trimmed.isNotEmpty && !trimmed.contains('⚠️')) {
        sections['contrarian']!.add(trimmed);
      }
    }

    return sections;
  }

  Widget _buildConfidenceBars(List<String> confidenceData) {
    final bars = <Widget>[];

    for (final data in confidenceData) {
      final parts = data.split(':');
      if (parts.length >= 2) {
        final team = parts[0].trim();
        final confidenceText = parts[1].trim();

        // Extract percentage
        final percentMatch = RegExp(r'(\d+)%').firstMatch(confidenceText);
        if (percentMatch != null) {
          final percent = int.parse(percentMatch.group(1)!);
          bars.add(_buildConfidenceBar(team, percent / 100));
        }
      }
    }

    if (bars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Community sentiment data available',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    return Column(
      children: bars,
    );
  }

  Widget _buildConfidenceBar(String team, double confidence) {
    // Determine color based on confidence level
    Color barColor;
    if (confidence >= 0.7) {
      barColor = Colors.green;
    } else if (confidence >= 0.5) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Team name and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(confidence * 100).toInt()}%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: confidence,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          barColor,
                          barColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sentiment emoji
          const SizedBox(height: 6),
          Text(
            _getSentimentEmoji(confidence),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _getSentimentEmoji(double confidence) {
    if (confidence >= 0.75) {
      return '😊 Very Confident';
    } else if (confidence >= 0.6) {
      return '🙂 Confident';
    } else if (confidence >= 0.5) {
      return '😐 Neutral';
    } else if (confidence >= 0.35) {
      return '😕 Concerned';
    } else {
      return '😟 Worried';
    }
  }

  Widget _buildCommunityInsights(List<String> insights) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.forum, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                'COMMUNITY INSIGHTS',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 12,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
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

  Widget _buildContrarianAlert(List<String> contrarianInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CONTRARIAN OPPORTUNITY',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...contrarianInfo.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trending_down,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info,
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Betting against public sentiment can provide value',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
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
