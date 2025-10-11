import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Breaking News Card
/// Displays recent news articles with timestamps and sources
/// Tappable to open full article in browser
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
    // Get news articles from metadata
    final articles = (cardData.metadata['articles'] as List<dynamic>?) ?? [];

    // Limit to top 3 articles for card display
    final displayArticles = articles.take(3).toList();

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

        // News Articles
        if (displayArticles.isEmpty)
          _buildFallbackContent(cardData)
        else
          ...displayArticles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value as Map<String, dynamic>;

            return Padding(
              padding: EdgeInsets.only(bottom: index < displayArticles.length - 1 ? 12 : 0),
              child: _buildArticleItem(context, article, index),
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
                '${articles.length} article${articles.length != 1 ? 's' : ''} found',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.trending_up,
                color: Colors.redAccent,
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

  Widget _buildArticleItem(BuildContext context, Map<String, dynamic> article, int index) {
    final title = article['title'] as String? ?? 'No title';
    final description = article['description'] as String? ?? '';
    final source = article['source'] as String? ?? 'Unknown';
    final url = article['url'] as String? ?? '';
    final publishedAt = article['publishedAt'] as DateTime?;
    final analysis = article['analysis'] as Map<String, dynamic>? ?? {};

    // Calculate time ago
    String timeAgo = 'Recently';
    if (publishedAt != null) {
      try {
        final diff = DateTime.now().difference(publishedAt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inDays}d ago';
        }
      } catch (e) {
        // Keep default timeAgo
      }
    }

    // Get sentiment for color coding
    final sentiment = analysis['sentiment'] as String? ?? 'neutral';
    Color sentimentColor = Colors.white.withOpacity(0.1);
    IconData sentimentIcon = Icons.article;

    if (sentiment == 'negative') {
      sentimentColor = Colors.red.withOpacity(0.1);
      sentimentIcon = Icons.warning_amber;
    } else if (sentiment == 'positive') {
      sentimentColor = Colors.green.withOpacity(0.1);
      sentimentIcon = Icons.trending_up;
    }

    return GestureDetector(
      onTap: () => _openArticle(url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sentimentColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title (max 2 lines)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              // Description (max 2 lines)
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Source and time
            Row(
              children: [
                Icon(
                  sentimentIcon,
                  size: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  source,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                // Read more indicator
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Open article URL in browser
  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening article: $e');
    }
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
