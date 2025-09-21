import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/boxing_event_model.dart';
import '../../../theme/app_theme.dart';

class ESPNPreviewTab extends StatelessWidget {
  final BoxingEvent event;

  const ESPNPreviewTab({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event preview header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.neonGreen.withOpacity(0.2),
                  AppTheme.surfaceBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neonGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.boxingGlove(PhosphorIconsStyle.fill),
                  size: 48,
                  color: AppTheme.neonGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  'FIGHT PREVIEW',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Key storylines
          _PreviewSection(
            title: 'KEY STORYLINES',
            icon: PhosphorIcons.newspaper(PhosphorIconsStyle.bold),
            items: [
              'Championship implications on the line',
              'Fighters meeting for the first time',
              'Winner moves closer to title shot',
              'High-stakes matchup with ranking implications',
            ],
          ),

          const SizedBox(height: 16),

          // What to watch for
          _PreviewSection(
            title: 'WHAT TO WATCH FOR',
            icon: PhosphorIcons.eye(PhosphorIconsStyle.bold),
            items: [
              'Opening round exchanges and pace setting',
              'Mid-round adjustments and corner strategy',
              'Conditioning in the championship rounds',
              'Judges\' scoring if it goes the distance',
            ],
          ),

          const SizedBox(height: 16),

          // Prediction placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningAmber.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.chartLine(PhosphorIconsStyle.bold),
                      size: 20,
                      color: AppTheme.warningAmber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EXPERT PREDICTIONS',
                      style: TextStyle(
                        color: AppTheme.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Expert predictions and odds will be available closer to the fight date.',
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // How to follow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.broadcast(PhosphorIconsStyle.bold),
                      size: 20,
                      color: AppTheme.neonGreen,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'HOW TO FOLLOW',
                      style: TextStyle(
                        color: AppTheme.neonGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FollowOption(
                  icon: PhosphorIcons.television(PhosphorIconsStyle.fill),
                  title: 'Watch Live',
                  description: 'Check local listings for broadcast information',
                ),
                const SizedBox(height: 12),
                _FollowOption(
                  icon: PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
                  title: 'Live Updates',
                  description: 'Follow round-by-round updates in the app',
                ),
                const SizedBox(height: 12),
                _FollowOption(
                  icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                  title: 'Notifications',
                  description: 'Get alerts for fight start and results',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _PreviewSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.neonGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      size: 14,
                      color: AppTheme.neonGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FollowOption({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.neonGreen.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.neonGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}