import 'package:flutter/material.dart';
import 'dart:ui';
import 'edge_card_types.dart';

/// Main Edge Card Widget
class EdgeCardWidget extends StatefulWidget {
  final EdgeCardData cardData;
  final VoidCallback onUnlock;
  final VoidCallback? onTap;
  final bool showAnimation;

  const EdgeCardWidget({
    Key? key,
    required this.cardData,
    required this.onUnlock,
    this.onTap,
    this.showAnimation = true,
  }) : super(key: key);

  @override
  State<EdgeCardWidget> createState() => _EdgeCardWidgetState();
}

class _EdgeCardWidgetState extends State<EdgeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showAnimation && widget.cardData.isFresh) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = EdgeCardConfigs.getConfig(widget.cardData.category);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.cardData.isLocked ? widget.onUnlock : widget.onTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed
                  ? 0.98
                  : _isHovered
                      ? 1.03
                      : _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: EdgeCardConfigs.getRarityGlowColor(
                        widget.cardData.rarity,
                      ).withOpacity(_glowAnimation.value * 0.5 + 0.2),
                      blurRadius: _isHovered ? 20 : 10,
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.cardData.isLocked
                      ? _buildLockedCard(config)
                      : _buildUnlockedCard(config),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLockedCard(EdgeCardConfig config) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Blur overlay for locked content
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
          
          // Card content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with badges
                _buildCardHeader(config),
                
                const SizedBox(height: 12),
                
                // Teaser content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cardData.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.cardData.teaserText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Partial info bar
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Unlock button
                _buildUnlockButton(),
              ],
            ),
          ),
          
          // Rarity indicator
          _buildRarityIndicator(),
        ],
      ),
    );
  }

  Widget _buildUnlockedCard(EdgeCardConfig config) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.gradientColors[0].withOpacity(0.9),
            config.gradientColors[1].withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Card content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with badges
                _buildCardHeader(config),
                
                const SizedBox(height: 12),
                
                // Full content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cardData.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.cardData.fullContent,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        if (widget.cardData.impactText != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Impact: ${widget.cardData.impactText}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Confidence indicator
                _buildConfidenceBar(),
              ],
            ),
          ),
          
          // Rarity indicator
          _buildRarityIndicator(),
          
          // Unlocked checkmark
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(EdgeCardConfig config) {
    return Row(
      children: [
        Icon(
          config.icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          config.title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        // Badges
        ...widget.cardData.badges.take(2).map((badge) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _buildBadge(badge),
        )),
      ],
    );
  }

  Widget _buildBadge(EdgeCardBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EdgeCardConfigs.getBadgeColor(badge).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EdgeCardConfigs.getBadgeColor(badge),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            EdgeCardConfigs.getBadgeIcon(badge),
            color: Colors.white,
            size: 12,
          ),
          if (badge == EdgeCardBadge.views && widget.cardData.viewCount != null) ...[
            const SizedBox(width: 2),
            Text(
              '${widget.cardData.viewCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnlockButton() {
    final cost = widget.cardData.calculateDynamicPrice(
      DateTime.now().add(const Duration(hours: 2)), // Example game time
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_open,
            color: Colors.black87,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Unlock for $cost BR',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Confidence',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(widget.cardData.confidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widget.cardData.confidence,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRarityIndicator() {
    final rarityColor = EdgeCardConfigs.getRarityColor(widget.cardData.rarity);
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              rarityColor.withOpacity(0.8),
              rarityColor,
              rarityColor.withOpacity(0.8),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}