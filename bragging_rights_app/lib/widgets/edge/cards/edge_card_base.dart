import 'package:flutter/material.dart';
import 'dart:ui';
import '../edge_card_types.dart';

/// Base Edge Card Widget
/// Handles common functionality: locked/unlocked states, purchase flow, rarity effects
class EdgeCardBase extends StatefulWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final Widget Function(BuildContext context, EdgeCardData cardData) contentBuilder;
  final bool showFullContent;

  const EdgeCardBase({
    Key? key,
    required this.cardData,
    required this.onPurchase,
    required this.contentBuilder,
    this.showFullContent = false,
  }) : super(key: key);

  @override
  State<EdgeCardBase> createState() => _EdgeCardBaseState();
}

class _EdgeCardBaseState extends State<EdgeCardBase> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Glow animation for rare/epic/legendary cards
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start glow for high-rarity cards
    if (_shouldGlow()) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  bool _shouldGlow() {
    return [
      EdgeCardRarity.rare,
      EdgeCardRarity.epic,
      EdgeCardRarity.legendary,
    ].contains(widget.cardData.rarity);
  }

  @override
  Widget build(BuildContext context) {
    final config = EdgeCardConfigs.getConfig(widget.cardData.category);
    final rarityColor = EdgeCardConfigs.getRarityColor(widget.cardData.rarity);
    final rarityGlow = EdgeCardConfigs.getRarityGlowColor(widget.cardData.rarity);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _shouldGlow()
                ? [
                    BoxShadow(
                      color: rarityGlow.withOpacity(_glowAnimation.value * 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: config.gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: rarityColor.withOpacity(0.8),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(config, rarityColor),

                      // Content
                      _buildContent(),

                      // Footer (purchase button or metadata)
                      _buildFooter(config),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(EdgeCardConfig config, Color rarityColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: rarityColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon and badges
          Row(
            children: [
              // Category icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rarityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  config.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getRarityLabel(widget.cardData.rarity),
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Badges
              ..._buildBadges(),
            ],
          ),

          // Age and expiry
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                widget.cardData.ageText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              if (widget.cardData.isExpiringSoon) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer, size: 12, color: Colors.red),
                      SizedBox(width: 2),
                      Text(
                        'EXPIRING SOON',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBadges() {
    return widget.cardData.badges.map((badge) {
      final badgeIcon = EdgeCardConfigs.getBadgeIcon(badge);
      final badgeColor = EdgeCardConfigs.getBadgeColor(badge);

      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.5)),
          ),
          child: Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildContent() {
    if (widget.cardData.isLocked && !widget.showFullContent) {
      return _buildLockedContent();
    } else {
      return _buildUnlockedContent();
    }
  }

  Widget _buildLockedContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teaser text (blurred)
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.cardData.teaserText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.cardData.impactText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.cardData.impactText!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Confidence indicator
          const SizedBox(height: 12),
          _buildConfidenceIndicator(),
        ],
      ),
    );
  }

  Widget _buildUnlockedContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom content from builder
          widget.contentBuilder(context, widget.cardData),

          // Confidence indicator
          const SizedBox(height: 12),
          _buildConfidenceIndicator(),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator() {
    final confidencePct = (widget.cardData.confidence * 100).toInt();
    final color = widget.cardData.confidence >= 0.8
        ? Colors.green
        : widget.cardData.confidence >= 0.6
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Icon(
          Icons.check_circle,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          'Confidence: $confidencePct%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.cardData.confidence,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(EdgeCardConfig config) {
    if (widget.cardData.isLocked && !widget.showFullContent) {
      return _buildPurchaseButton();
    } else {
      return _buildMetadataFooter();
    }
  }

  Widget _buildPurchaseButton() {
    final dynamicPrice = widget.cardData.calculateDynamicPrice(
      widget.cardData.expiresAt ?? DateTime.now().add(const Duration(hours: 24)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNLOCK FOR',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.stars,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$dynamicPrice BR',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dynamicPrice != widget.cardData.currentCost) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${widget.cardData.currentCost}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Purchase button
          ElevatedButton(
            onPressed: widget.onPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_open, size: 18),
                SizedBox(width: 6),
                Text(
                  'UNLOCK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Source
          if (widget.cardData.metadata['source'] != null) ...[
            Icon(
              Icons.source,
              size: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              widget.cardData.metadata['source'].toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],

          const Spacer(),

          // View count (if available)
          if (widget.cardData.viewCount != null) ...[
            Icon(
              Icons.remove_red_eye,
              size: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.cardData.viewCount} views',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRarityLabel(EdgeCardRarity rarity) {
    switch (rarity) {
      case EdgeCardRarity.common:
        return 'COMMON';
      case EdgeCardRarity.uncommon:
        return 'UNCOMMON';
      case EdgeCardRarity.rare:
        return 'RARE';
      case EdgeCardRarity.epic:
        return 'EPIC';
      case EdgeCardRarity.legendary:
        return '⭐ LEGENDARY ⭐';
    }
  }
}
