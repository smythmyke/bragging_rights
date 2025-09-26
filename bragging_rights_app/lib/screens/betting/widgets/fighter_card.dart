import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/fight_card_model.dart';
import '../../../theme/app_theme.dart';
import '../fight_card_grid_screen.dart';

class FighterCard extends StatelessWidget {
  final Fight fight;
  final String fighterId;
  final String fighterName;
  final String record;
  final String country;
  final String? odds;
  final String? imageUrl;  // Add image URL parameter
  final bool isLeft;
  final FightPickState? pick;
  final VoidCallback onTap;

  const FighterCard({
    Key? key,
    required this.fight,
    required this.fighterId,
    required this.fighterName,
    required this.record,
    required this.country,
    this.odds,
    this.imageUrl,
    required this.isLeft,
    this.pick,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSelected = pick?.winnerId == fighterId;
    final isTie = pick?.method == 'TIE';
    final isOpponentSelected = pick?.winnerId != null &&
                               pick?.winnerId != fighterId &&
                               !isTie;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [AppTheme.neonGreen.withOpacity(0.2), AppTheme.neonGreen.withOpacity(0.1)]
                    : isTie
                        ? [AppTheme.warningAmber.withOpacity(0.2), AppTheme.warningAmber.withOpacity(0.1)]
                        : [AppTheme.surfaceBlue.withOpacity(0.6), AppTheme.cardBlue.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected
                    ? AppTheme.neonGreen
                    : isTie
                        ? AppTheme.warningAmber
                        : isOpponentSelected
                            ? AppTheme.borderCyan.withOpacity(0.2)
                            : AppTheme.borderCyan.withOpacity(0.3),
                width: isSelected || isTie ? 2 : 1,
              ),
              boxShadow: isSelected || isTie
                  ? AppTheme.neonGlow(
                      color: isSelected ? AppTheme.neonGreen : AppTheme.warningAmber,
                      intensity: 0.5,
                    )
                  : null,
              borderRadius: BorderRadius.only(
                bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
                bottomRight: !isLeft ? const Radius.circular(8) : Radius.zero,
                topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
                topRight: !isLeft ? const Radius.circular(8) : Radius.zero,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Fighter avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.neonGreen
                          : isTie
                              ? AppTheme.warningAmber
                              : AppTheme.borderCyan.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: isSelected || isTie
                        ? [
                            BoxShadow(
                              color: (isSelected ? AppTheme.neonGreen : AppTheme.warningAmber).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: _buildFighterImage(isSelected, isTie),
                  ),
                ),
                const SizedBox(height: 8),
                // Fighter name
                Text(
                  fighterName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.neonGreen
                        : isTie
                            ? AppTheme.warningAmber
                            : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: isSelected || isTie
                        ? [
                            Shadow(
                              color: (isSelected ? AppTheme.neonGreen : AppTheme.warningAmber).withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Record
                Text(
                  record,
                  style: TextStyle(
                    color: isSelected || isTie
                        ? (isSelected ? AppTheme.neonGreen : AppTheme.warningAmber).withOpacity(0.8)
                        : AppTheme.primaryCyan.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Odds badge removed - using point system instead
                // Keep odds parameter for potential future use
              ],
            ),
          ),
          // Method indicator badge (top-right corner)
          if (isSelected && pick?.method != null && pick?.method != 'TIE')
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMethodColor(pick?.method ?? ''),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _getMethodColor(pick?.method ?? '').withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  pick?.method ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFighterImage(bool isSelected, bool isTie) {
    // Use provided imageUrl first, then try to build from fighter ID
    String? finalImageUrl = imageUrl;

    if (finalImageUrl == null) {
      // Fallback to building URL from numeric ESPN ID
      final isNumericId = RegExp(r'^\d+$').hasMatch(fighterId);
      finalImageUrl = isNumericId
          ? 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png'
          : null;
    }

    if (finalImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: finalImageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [AppTheme.neonGreen.withOpacity(0.3), AppTheme.neonGreen.withOpacity(0.1)]
                  : isTie
                      ? [AppTheme.warningAmber.withOpacity(0.3), AppTheme.warningAmber.withOpacity(0.1)]
                      : [AppTheme.surfaceBlue, AppTheme.cardBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSelected ? AppTheme.neonGreen : AppTheme.primaryCyan.withOpacity(0.5),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(isSelected, isTie),
      );
    }

    return _buildFallbackAvatar(isSelected, isTie);
  }

  Widget _buildFallbackAvatar(bool isSelected, bool isTie) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [AppTheme.neonGreen.withOpacity(0.3), AppTheme.neonGreen.withOpacity(0.1)]
              : isTie
                  ? [AppTheme.warningAmber.withOpacity(0.3), AppTheme.warningAmber.withOpacity(0.1)]
                  : [AppTheme.surfaceBlue, AppTheme.cardBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          fighterName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join(),
          style: TextStyle(
            color: isSelected
                ? AppTheme.neonGreen
                : isTie
                    ? AppTheme.warningAmber
                    : AppTheme.primaryCyan.withOpacity(0.7),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'KO':
      case 'KO/TKO':
        return const Color(0xFFFF6600); // Orange
      case 'TKO':
        return const Color(0xFFFF9933); // Light orange
      case 'SUB':
      case 'SUBMISSION':
        return const Color(0xFFFF00FF); // Magenta
      case 'DEC':
      case 'DECISION':
        return const Color(0xFF00FFFF); // Cyan
      default:
        return AppTheme.primaryCyan;
    }
  }
}