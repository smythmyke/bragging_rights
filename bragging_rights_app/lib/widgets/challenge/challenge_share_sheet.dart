import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_theme.dart';

class ChallengeShareSheet extends StatelessWidget {
  final Challenge challenge;
  final String shareLink;

  const ChallengeShareSheet({
    Key? key,
    required this.challenge,
    required this.shareLink,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBlue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Share Challenge',
                  style: AppTheme.neonText(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Anyone with this link can accept your challenge',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),

          // Event info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderCyan.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getSportIcon(challenge.sportType),
                      color: AppTheme.primaryCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        challenge.eventName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatEventDate(challenge.eventDate),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Share options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.message,
                label: 'SMS',
                color: AppTheme.primaryCyan,
                onTap: () => _shareViaSMS(context),
              ),
              _ShareOption(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _shareViaWhatsApp(context),
              ),
              _ShareOption(
                icon: Icons.copy,
                label: 'Copy',
                color: AppTheme.warningAmber,
                onTap: () => _copyLink(context),
              ),
              _ShareOption(
                icon: Icons.share,
                label: 'More',
                color: AppTheme.secondaryCyan,
                onTap: () => _shareViaSystem(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Link preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderCyan.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 20,
                  color: AppTheme.primaryCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shareLink,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getShareMessage() {
    final sportEmoji = _getSportEmoji(challenge.sportType);
    final dateStr = _formatEventDate(challenge.eventDate);

    return '''
$sportEmoji CHALLENGE FROM ${challenge.challengerName.toUpperCase()}! $sportEmoji

Event: ${challenge.eventName}
Date: $dateStr

Think you know ${_getSportName(challenge.sportType)} better? Accept my challenge and prove it!

$shareLink

Don't have the app? Download Bragging Rights and join the competition!
''';
  }

  Future<void> _shareViaSMS(BuildContext context) async {
    try {
      final message = _getShareMessage();
      final uri = Uri(
        scheme: 'sms',
        path: '',
        queryParameters: {'body': message},
      );

      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await ChallengeService().incrementShareCount(challenge.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to share via SMS');
      }
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      final message = _getShareMessage();
      final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        await ChallengeService().incrementShareCount(challenge.id);
        if (context.mounted) {
          Navigator.pop(context);
        }
      } else {
        // Fallback to web WhatsApp
        final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          await ChallengeService().incrementShareCount(challenge.id);
          if (context.mounted) {
            Navigator.pop(context);
          }
        } else {
          if (context.mounted) {
            _showError(context, 'WhatsApp not available');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to share via WhatsApp');
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: shareLink));
      await ChallengeService().incrementShareCount(challenge.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link copied to clipboard!'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to copy link');
      }
    }
  }

  Future<void> _shareViaSystem(BuildContext context) async {
    try {
      final message = _getShareMessage();
      await Share.share(
        message,
        subject: 'Bragging Rights Challenge - ${challenge.eventName}',
      );
      await ChallengeService().incrementShareCount(challenge.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to share');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorPink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'mma':
      case 'boxing':
        return Icons.sports_mma;
      case 'nfl':
        return Icons.sports_football;
      case 'nba':
        return Icons.sports_basketball;
      case 'nhl':
        return Icons.sports_hockey;
      case 'mlb':
        return Icons.sports_baseball;
      case 'soccer':
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  String _getSportEmoji(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'mma':
      case 'boxing':
        return '🥊';
      case 'nfl':
        return '🏈';
      case 'nba':
        return '🏀';
      case 'nhl':
        return '🏒';
      case 'mlb':
        return '⚾';
      case 'soccer':
        return '⚽';
      default:
        return '🏆';
    }
  }

  String _getSportName(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'mma':
        return 'MMA';
      case 'boxing':
        return 'Boxing';
      case 'nfl':
        return 'Football';
      case 'nba':
        return 'Basketball';
      case 'nhl':
        return 'Hockey';
      case 'mlb':
        return 'Baseball';
      case 'soccer':
        return 'Soccer';
      default:
        return 'Sports';
    }
  }

  String _formatEventDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final month = months[date.month - 1];
    final day = date.day;
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $hour:$minute $period';
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}