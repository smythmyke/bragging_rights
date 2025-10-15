import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Star-based confidence selector (1-5 stars)
/// Used in simple betting system to apply point multipliers
class ConfidenceSelector extends StatelessWidget {
  final int confidence;
  final Function(int) onConfidenceChanged;
  final bool enabled;
  final double size;

  const ConfidenceSelector({
    Key? key,
    required this.confidence,
    required this.onConfidenceChanged,
    this.enabled = true,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final isFilled = starNumber <= confidence;

        return GestureDetector(
          onTap: enabled ? () => onConfidenceChanged(starNumber) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: enabled
                  ? (isFilled ? _getStarColor(starNumber) : Colors.grey[400])
                  : Colors.grey[600],
              size: size,
            ),
          ),
        );
      }),
    );
  }

  /// Get star color based on confidence level
  Color _getStarColor(int level) {
    switch (level) {
      case 1:
        return Colors.grey[400]!;  // 1x multiplier
      case 2:
        return Colors.blue[400]!;  // 1.5x multiplier
      case 3:
        return Colors.green[400]!; // 2x multiplier
      case 4:
        return Colors.orange[400]!; // 2.5x multiplier
      case 5:
        return Colors.red[400]!;   // 3x multiplier
      default:
        return Colors.grey;
    }
  }
}

/// Confidence selector with label and multiplier display
class LabeledConfidenceSelector extends StatelessWidget {
  final int confidence;
  final Function(int) onConfidenceChanged;
  final bool enabled;
  final String? label;
  final bool showMultiplier;

  const LabeledConfidenceSelector({
    Key? key,
    required this.confidence,
    required this.onConfidenceChanged,
    this.enabled = true,
    this.label,
    this.showMultiplier = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final multiplier = _getMultiplier(confidence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConfidenceSelector(
              confidence: confidence,
              onConfidenceChanged: onConfidenceChanged,
              enabled: enabled,
            ),
            if (showMultiplier) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${multiplier}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? AppTheme.primaryCyan : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  double _getMultiplier(int confidence) {
    switch (confidence) {
      case 1: return 1.0;
      case 2: return 1.5;
      case 3: return 2.0;
      case 4: return 2.5;
      case 5: return 3.0;
      default: return 1.0;
    }
  }
}

/// Compact confidence display (read-only)
class ConfidenceDisplay extends StatelessWidget {
  final int confidence;
  final double size;
  final bool showMultiplier;

  const ConfidenceDisplay({
    Key? key,
    required this.confidence,
    this.size = 16.0,
    this.showMultiplier = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final multiplier = _getMultiplier(confidence);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          final isFilled = starNumber <= confidence;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: isFilled ? _getStarColor(starNumber) : Colors.grey[400],
              size: size,
            ),
          );
        }),
        if (showMultiplier) ...[
          const SizedBox(width: 4),
          Text(
            '(${multiplier}x)',
            style: TextStyle(
              fontSize: size * 0.75,
              color: AppTheme.primaryCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Color _getStarColor(int level) {
    switch (level) {
      case 1: return Colors.grey[400]!;
      case 2: return Colors.blue[400]!;
      case 3: return Colors.green[400]!;
      case 4: return Colors.orange[400]!;
      case 5: return Colors.red[400]!;
      default: return Colors.grey;
    }
  }

  double _getMultiplier(int confidence) {
    switch (confidence) {
      case 1: return 1.0;
      case 2: return 1.5;
      case 3: return 2.0;
      case 4: return 2.5;
      case 5: return 3.0;
      default: return 1.0;
    }
  }
}
