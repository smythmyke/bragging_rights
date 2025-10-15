import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/simple_bet.dart';
import 'confidence_selector.dart';

/// Card widget for displaying and selecting simple bets
/// Replaces odds-based bet cards in simple betting system
class SimpleBetCard extends StatelessWidget {
  final SimpleBet bet;
  final bool isSelected;
  final Function(bool) onSelectionChanged;
  final Function(int) onConfidenceChanged;
  final Color? accentColor;
  final bool isRequired;

  const SimpleBetCard({
    Key? key,
    required this.bet,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onConfidenceChanged,
    this.accentColor,
    this.isRequired = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = accentColor ?? AppTheme.primaryCyan;

    return GestureDetector(
      onTap: () => onSelectionChanged(!isSelected),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    cardColor.withOpacity(0.2),
                    cardColor.withOpacity(0.1),
                  ]
                : [
                    const Color(0xFF141829),
                    const Color(0xFF1A1F3A).withOpacity(0.8),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cardColor
                : AppTheme.primaryCyan.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cardColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bet description and points
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bet.description,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[300],
                      ),
                    ),
                  ),
                  _buildPointsBadge(),
                ],
              ),

              if (isRequired) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorPink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorPink,
                    ),
                  ),
                ),
              ],

              // Confidence selector (only shown when selected)
              if (isSelected) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.grey, height: 1),
                const SizedBox(height: 12),
                LabeledConfidenceSelector(
                  confidence: bet.confidence,
                  onConfidenceChanged: onConfidenceChanged,
                  enabled: true,
                  label: 'Confidence:',
                  showMultiplier: true,
                ),
                const SizedBox(height: 8),
                _buildPotentialPoints(),
              ],

              // Selection indicator
              if (!isSelected) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to add to bet slip',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build base points badge
  Widget _buildPointsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.neonGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.neonGreen.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${bet.basePoints}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.neonGreen,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'pts',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.neonGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Build potential points display
  Widget _buildPotentialPoints() {
    final potential = bet.potentialPoints;

    return Row(
      children: [
        const Icon(
          Icons.trending_up,
          size: 16,
          color: AppTheme.neonGreen,
        ),
        const SizedBox(width: 4),
        Text(
          'Potential: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        Text(
          '${potential.toStringAsFixed(1)} pts',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.neonGreen,
          ),
        ),
      ],
    );
  }
}

/// Compact version for bet slip display
class SimpleBetCardCompact extends StatelessWidget {
  final SimpleBet bet;
  final VoidCallback? onRemove;
  final Color? accentColor;

  const SimpleBetCardCompact({
    Key? key,
    required this.bet,
    this.onRemove,
    this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardColor = accentColor ?? AppTheme.primaryCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141829),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cardColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bet.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                  color: Colors.grey[400],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ConfidenceDisplay(
                confidence: bet.confidence,
                size: 14,
                showMultiplier: true,
              ),
              Text(
                '${bet.potentialPoints.toStringAsFixed(1)} pts',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
