/// MMA ID FIX PATCH - Complete fix for MMA event ID generation
///
/// Apply this fix to optimized_games_service.dart to ensure MMA events
/// always get numeric IDs that work with MMAService.

// Step 1: Add this import at the top of optimized_games_service.dart:
// import 'mma_id_fix.dart';

// Step 2: Replace the entire _groupByTimeWindows method with this version:

/*
  List<GameModel> _groupByTimeWindows(List<GameModel> fights, String sport) {
    const windowHours = 6; // 6-hour window for same event
    final Map<String, List<GameModel>> groups = {};

    for (final fight in fights) {
      bool addedToGroup = false;

      for (final entry in groups.entries) {
        final groupTime = DateTime.parse(entry.key);
        final timeDiff = fight.gameTime.difference(groupTime).inHours.abs();

        if (timeDiff <= windowHours) {
          entry.value.add(fight);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groups[fight.gameTime.toIso8601String()] = [fight];
      }
    }

    // Convert groups to events
    final List<GameModel> groupedEvents = [];

    for (final entry in groups.entries) {
      final eventFights = entry.value;
      if (eventFights.isEmpty) continue;

      // Sort by time - latest is usually main event
      eventFights.sort((a, b) => a.gameTime.compareTo(b.gameTime));

      final mainEvent = eventFights.last;
      final eventName = '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}';

      // CRITICAL FIX: Generate appropriate IDs based on sport type
      final ids = MMAIdFix.getEventIds(sport, eventFights.first.gameTime, eventName);

      final groupedEvent = GameModel(
        id: ids['id']!,
        espnId: ids['espnId'],  // Pseudo-ESPN ID for MMA, null for others
        sport: sport.toUpperCase(),
        homeTeam: mainEvent.homeTeam,
        awayTeam: mainEvent.awayTeam,
        gameTime: eventFights.first.gameTime,
        status: mainEvent.status,
        venue: mainEvent.venue,
        broadcast: mainEvent.broadcast,
        league: eventName,
        homeTeamLogo: mainEvent.homeTeamLogo,
        awayTeamLogo: mainEvent.awayTeamLogo,
        isCombatSport: true,
        totalFights: eventFights.length,
        mainEventFighters: eventName,
        fights: eventFights.map((f) => {
          'id': f.id,
          'fighter1': f.awayTeam,
          'fighter2': f.homeTeam,
          'time': f.gameTime.toIso8601String(),
          'odds': f.odds,
        }).toList(),
      );

      debugPrint('    Contains ${eventFights.length} fights');

      groupedEvents.add(groupedEvent);
    }

    return groupedEvents;
  }
*/

// Step 3: Also update the matching section in _groupCombatSportsByEvent where ESPN IDs are assigned.
// Look for this line around line 826:
//   final eventId = (sport.toUpperCase() == 'MMA' && espnEventId != null)
//       ? espnEventId
//       : safeId;
//
// Make sure it's there and working. If ESPN events don't match, the time-based grouping
// will now generate proper numeric IDs for MMA.

// Step 4: After applying these changes, hot reload the app (press 'r' in the terminal)

// Step 5: Clear the app data and Firestore cache to ensure fresh IDs are generated