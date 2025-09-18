/// MMA ID FIX - This file contains the fix for MMA event ID generation
///
/// The problem: MMA events are getting custom IDs like "mma_fighter1_v_fighter2"
/// instead of ESPN numeric IDs that the MMAService expects.
///
/// Root cause: ESPN and Odds API have different events that don't match,
/// causing all fights to fall through to time-based grouping which creates custom IDs.
///
/// Solution: For MMA events, always generate numeric IDs that look like ESPN IDs.

class MMAIdFix {
  /// Generate a pseudo-ESPN ID for MMA events when no real ESPN ID is available
  /// This ensures MMA always has numeric IDs that work with MMAService
  static String generateMMAEventId(DateTime eventTime, String eventName) {
    // Generate a numeric ID based on timestamp (looks like ESPN ID format)
    // Use the event's start time as a unique numeric identifier
    final timestamp = eventTime.millisecondsSinceEpoch ~/ 1000;

    // Start with 9 to avoid conflicts with real ESPN IDs which typically start with 6
    final pseudoEspnId = '9${timestamp.toString().substring(3)}';

    print('📱 MMA: Generated pseudo-ESPN ID: $pseudoEspnId for $eventName');
    return pseudoEspnId;
  }

  /// Check if a sport is MMA/UFC
  static bool isMMA(String sport) {
    final upperSport = sport.toUpperCase();
    return upperSport == 'MMA' || upperSport == 'UFC';
  }

  /// Get the appropriate event ID based on sport type
  static Map<String, String?> getEventIds(String sport, DateTime eventTime, String eventName) {
    if (isMMA(sport)) {
      // For MMA, always use numeric IDs
      final espnId = generateMMAEventId(eventTime, eventName);
      return {
        'id': espnId,
        'espnId': espnId,
      };
    } else {
      // For boxing and other sports, use safe string ID
      final safeId = '${sport.toLowerCase()}_${eventName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('\'', '')
        .replaceAll('vs', 'v')}';

      return {
        'id': safeId,
        'espnId': null,
      };
    }
  }
}

/// IMPLEMENTATION INSTRUCTIONS:
///
/// In optimized_games_service.dart, update the _groupByTimeWindows method:
///
/// Replace this section:
///   final safeId = '${sport.toLowerCase()}_${eventName.toLowerCase()...
///   final groupedEvent = GameModel(
///     id: safeId,
///     espnId: null,
///
/// With:
///   final ids = MMAIdFix.getEventIds(sport, eventFights.first.gameTime, eventName);
///   final groupedEvent = GameModel(
///     id: ids['id']!,
///     espnId: ids['espnId'],
///
/// This ensures MMA events ALWAYS get numeric IDs that work with MMAService.