import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ModeSelectionDialog extends StatelessWidget {
  final Map<String, dynamic> navigationArgs;
  
  const ModeSelectionDialog({
    super.key,
    required this.navigationArgs,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.gameController,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose Your Pick Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like to make your picks?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Quick Pick Option
            _ModeCard(
              icon: PhosphorIconsRegular.lightning,
              iconColor: Colors.orange,
              title: 'Quick Pick',
              subtitle: 'Swipe to pick winners fast',
              features: const [
                'Swipe right/left for picks',
                'See key stats only',
                'Perfect for casual players',
                '~2 minutes to complete',
              ],
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/quick-pick',
                  arguments: navigationArgs,
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Detailed Mode Option
            _ModeCard(
              icon: PhosphorIconsRegular.listChecks,
              iconColor: Colors.blue,
              title: 'Detailed Mode',
              subtitle: 'Traditional selection with all props',
              features: const [
                'View all betting props',
                'See detailed statistics',
                'Perfect for serious players',
                '~5-10 minutes to complete',
              ],
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/bet-selection',
                  arguments: navigationArgs,
                );
              },
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<String> features;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.arrowRight,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.check,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}