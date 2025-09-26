import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

enum EventType { mainEvent, coMain, titleFight, regular }

class EventBadge extends StatelessWidget {
  final EventType type;
  final String? customText;

  const EventBadge({
    Key? key,
    required this.type,
    this.customText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
        boxShadow: AppTheme.neonGlow(
          color: _getGlowColor(),
          intensity: 0.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getIcon(),
          const SizedBox(width: 6),
          Text(
            customText ?? _getText(),
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (type) {
      case EventType.mainEvent:
        return [
          AppTheme.warningAmber.withOpacity(0.3),
          AppTheme.warningAmber.withOpacity(0.15),
        ];
      case EventType.coMain:
        return [
          const Color(0xFFC0C0C0).withOpacity(0.3),
          const Color(0xFFC0C0C0).withOpacity(0.15),
        ];
      case EventType.titleFight:
        return [
          AppTheme.errorPink.withOpacity(0.3),
          AppTheme.errorPink.withOpacity(0.15),
        ];
      case EventType.regular:
        return [
          AppTheme.primaryCyan.withOpacity(0.2),
          AppTheme.primaryCyan.withOpacity(0.1),
        ];
    }
  }

  Color _getBorderColor() {
    switch (type) {
      case EventType.mainEvent:
        return AppTheme.warningAmber.withOpacity(0.6);
      case EventType.coMain:
        return const Color(0xFFC0C0C0).withOpacity(0.6);
      case EventType.titleFight:
        return AppTheme.errorPink.withOpacity(0.6);
      case EventType.regular:
        return AppTheme.primaryCyan.withOpacity(0.4);
    }
  }

  Color _getGlowColor() {
    switch (type) {
      case EventType.mainEvent:
        return AppTheme.warningAmber;
      case EventType.coMain:
        return const Color(0xFFC0C0C0);
      case EventType.titleFight:
        return AppTheme.errorPink;
      case EventType.regular:
        return AppTheme.primaryCyan;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case EventType.mainEvent:
        return AppTheme.warningAmber;
      case EventType.coMain:
        return const Color(0xFFC0C0C0);
      case EventType.titleFight:
        return AppTheme.errorPink;
      case EventType.regular:
        return AppTheme.primaryCyan;
    }
  }

  Widget _getIcon() {
    switch (type) {
      case EventType.mainEvent:
        return const Text(
          '👑',
          style: TextStyle(fontSize: 14),
        );
      case EventType.coMain:
        return const Text(
          '⭐',
          style: TextStyle(fontSize: 14),
        );
      case EventType.titleFight:
        return const Text(
          '🏆',
          style: TextStyle(fontSize: 14),
        );
      case EventType.regular:
        return const Icon(
          Icons.sports_mma,
          size: 14,
          color: AppTheme.primaryCyan,
        );
    }
  }

  String _getText() {
    switch (type) {
      case EventType.mainEvent:
        return 'MAIN EVENT';
      case EventType.coMain:
        return 'CO-MAIN';
      case EventType.titleFight:
        return 'TITLE FIGHT';
      case EventType.regular:
        return 'FIGHT CARD';
    }
  }
}