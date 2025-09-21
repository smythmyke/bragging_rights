import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../../models/boxing_event_model.dart';
import '../../../theme/app_theme.dart';

class EventInfoTab extends StatelessWidget {
  final BoxingEvent event;

  const EventInfoTab({
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
          // Event poster if available
          if (event.posterUrl != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  event.posterUrl!,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIcons.boxingGlove(PhosphorIconsStyle.light),
                          size: 64,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Event date and time
          _InfoCard(
            icon: PhosphorIcons.calendar(PhosphorIconsStyle.bold),
            title: 'DATE & TIME',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(event.date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(event.date),
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _CountdownTimer(eventDate: event.date),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Venue information
          _InfoCard(
            icon: PhosphorIcons.mapPin(PhosphorIconsStyle.bold),
            title: 'VENUE',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.venue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.location,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Promotion information
          _InfoCard(
            icon: PhosphorIcons.megaphone(PhosphorIconsStyle.bold),
            title: 'PROMOTION',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.promotion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (event.coPromotions != null && event.coPromotions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Co-Promotions:',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...event.coPromotions!.map((promo) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.dot(PhosphorIconsStyle.fill),
                          size: 8,
                          color: AppTheme.neonGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          promo,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),

          if (event.ringAnnouncers != null && event.ringAnnouncers!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              icon: PhosphorIcons.microphone(PhosphorIconsStyle.bold),
              title: 'RING ANNOUNCERS',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: event.ringAnnouncers!.map((announcer) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    announcer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],

          if (event.tvAnnouncers != null && event.tvAnnouncers!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              icon: PhosphorIcons.television(PhosphorIconsStyle.bold),
              title: 'COMMENTARY TEAM',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: event.tvAnnouncers!.map((announcer) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    announcer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppTheme.neonGreen,
              ),
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
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime eventDate;

  const _CountdownTimer({required this.eventDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _timeUntil;

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeUntil = widget.eventDate.difference(now);
    });

    if (_timeUntil.inSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), _updateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timeUntil.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.errorPink.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.errorPink, width: 1),
        ),
        child: const Text(
          'EVENT COMPLETED',
          style: TextStyle(
            color: AppTheme.errorPink,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final days = _timeUntil.inDays;
    final hours = _timeUntil.inHours % 24;
    final minutes = _timeUntil.inMinutes % 60;
    final seconds = _timeUntil.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.neonGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.neonGreen, width: 1),
      ),
      child: Text(
        '${days}d ${hours}h ${minutes}m ${seconds}s',
        style: const TextStyle(
          color: AppTheme.neonGreen,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}