import 'package:flutter/material.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Breaking News Card
/// Displays recent headlines with timestamps and sources
class BreakingNewsCard extends StatelessWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final bool showFullContent;

  const BreakingNewsCard({
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
    // Parse headlines from full content
    final lines = cardData.fullContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

    // Extract headlines (lines that start with numbers)
    final headlines = <String>[];
    for (final line in lines) {
      if (RegExp(r'^\d+\.').hasMatch(line.trim())) {
        headlines.add(line.trim().replaceFirst(RegExp(r'^\d+\.\s*'), ''));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.red, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'BREAKING',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Latest Updates',
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

        // Headlines
        if (headlines.isEmpty)
          _buildFallbackContent(cardData)
        else
          ...headlines.asMap().entries.map((entry) {
            final index = entry.key;
            final headline = entry.value;

            return Padding(
              padding: EdgeInsets.only(bottom: index < headlines.length - 1 ? 12 : 0),
              child: _buildHeadlineItem(headline, index),
            );
          }).toList(),

        const SizedBox(height: 16),

        // Article count
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.article,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${cardData.metadata['articleCount'] ?? headlines.length} articles found',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.trending_up,
                color: Colors.amber,
                size: 16,
              ),
            ],
          ),
        ),

        // Impact text
        if (cardData.impactText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cardData.impactText!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeadlineItem(String headline, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Headline text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Just now',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrow icon
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackContent(EdgeCardData cardData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        cardData.fullContent,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
