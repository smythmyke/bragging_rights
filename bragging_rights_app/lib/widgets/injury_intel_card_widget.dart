import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/intel_card_model.dart';
import '../theme/app_theme.dart';

class InjuryIntelCardWidget extends StatelessWidget {
  final IntelCard card;
  final bool owned;
  final VoidCallback onPurchase;
  final VoidCallback? onView;

  const InjuryIntelCardWidget({
    super.key,
    required this.card,
    required this.owned,
    required this.onPurchase,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a5f), Color(0xFF2a4a6f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: owned ? AppTheme.neonGreen : AppTheme.primaryCyan,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (owned ? AppTheme.neonGreen : AppTheme.primaryCyan).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
                color: AppTheme.warningAmber,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (owned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OWNED',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            card.description,
            style: const TextStyle(
              color: Color(0xFFBBBBBB),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),

          // Footer: Price and Expiration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Price Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryCyan, Color(0xFF0099cc)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.coins(PhosphorIconsStyle.fill),
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${card.brCost} BR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Expiration
              if (card.expiresAt != null)
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.timer(PhosphorIconsStyle.regular),
                      size: 14,
                      color: const Color(0xFF999999),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: ${card.timeUntilExpiration}',
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: owned
                  ? onView
                  : (card.isExpired ? null : onPurchase),
              style: ElevatedButton.styleFrom(
                backgroundColor: owned
                    ? AppTheme.neonGreen
                    : (card.isExpired
                        ? Colors.grey.shade800
                        : AppTheme.warningAmber),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                owned
                    ? 'VIEW INTEL'
                    : (card.isExpired
                        ? 'EXPIRED'
                        : '💰 GET INTEL - ${card.brCost} BR'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
