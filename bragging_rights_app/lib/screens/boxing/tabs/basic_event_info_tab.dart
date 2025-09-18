import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../../models/boxing_event_model.dart';
import '../../../theme/app_theme.dart';

class BasicEventInfoTab extends StatelessWidget {
  final BoxingEvent event;

  const BasicEventInfoTab({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Data source warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningAmber.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.info(PhosphorIconsStyle.fill),
                  size: 24,
                  color: AppTheme.warningAmber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limited Information Available',
                        style: TextStyle(
                          color: AppTheme.warningAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Using basic event data. Full fight card and fighter details not available.',
                        style: TextStyle(
                          color: AppTheme.warningAmber.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Event details card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Event title
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(event.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getStatusColor(event.status),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusText(event.status),
                          style: TextStyle(
                            color: _getStatusColor(event.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date & Time
                      _InfoRow(
                        icon: PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                        label: 'DATE',
                        value: DateFormat('EEEE, MMMM d, yyyy').format(event.date),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: PhosphorIcons.clock(PhosphorIconsStyle.bold),
                        label: 'TIME',
                        value: DateFormat('h:mm a').format(event.date),
                      ),

                      if (event.venue.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
                          label: 'VENUE',
                          value: event.venue,
                        ),
                      ],

                      if (event.location.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: PhosphorIcons.globe(PhosphorIconsStyle.bold),
                          label: 'LOCATION',
                          value: event.location,
                        ),
                      ],

                      if (event.broadcasters.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: PhosphorIcons.television(PhosphorIconsStyle.bold),
                          label: 'BROADCAST',
                          value: event.broadcasters.first,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Additional info message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIcons.boxingGlove(PhosphorIconsStyle.light),
                  size: 48,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'For complete fight card and fighter details',
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Check back closer to the event date',
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.live:
        return AppTheme.errorPink;
      case EventStatus.completed:
        return Colors.grey;
      case EventStatus.upcoming:
      default:
        return AppTheme.neonGreen;
    }
  }

  String _getStatusText(EventStatus status) {
    switch (status) {
      case EventStatus.live:
        return 'LIVE NOW';
      case EventStatus.completed:
        return 'COMPLETED';
      case EventStatus.upcoming:
      default:
        return 'UPCOMING';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.neonGreen,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}