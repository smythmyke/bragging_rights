import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'edge/sports/espn_nfl_service.dart';
import 'edge/sports/espn_nba_service.dart';
import 'edge/sports/espn_nhl_service.dart';
import 'edge/sports/espn_mlb_service.dart';

/// Service that periodically checks ESPN API to update game completion status
/// This ensures games transition from 'scheduled' -> 'final' to trigger bet settlement
class GameStatusUpdater {
  static final GameStatusUpdater _instance = GameStatusUpdater._internal();
  factory GameStatusUpdater() => _instance;
  GameStatusUpdater._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ESPN service instances (free API, no rate limits)
  final EspnNflService _nflService = EspnNflService();
  final EspnNbaService _nbaService = EspnNbaService();
  final EspnNhlService _nhlService = EspnNhlService();
  final EspnMlbService _mlbService = EspnMlbService();

  Timer? _updateTimer;
  bool _isRunning = false;

  /// Start monitoring games for completion
  /// Checks every 5 minutes for games that may have finished
  void startMonitoring() {
    if (_isRunning) {
      debugPrint('⚠️ [GAME STATUS UPDATER] Already running');
      return;
    }

    debugPrint('🎮 [GAME STATUS UPDATER] Starting monitoring service...');
    _isRunning = true;

    // Run immediately on start
    _updateGameStatuses();

    // Then check every 5 minutes
    _updateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateGameStatuses();
    });

    debugPrint('✅ [GAME STATUS UPDATER] Monitoring started (checks every 5 minutes)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    debugPrint('🛑 [GAME STATUS UPDATER] Stopping monitoring service...');
    _updateTimer?.cancel();
    _updateTimer = null;
    _isRunning = false;
  }

  /// Main update logic - checks all active games and updates their status
  Future<void> _updateGameStatuses() async {
    if (!_isRunning) return;

    debugPrint('\n🔄 [GAME STATUS UPDATER] Checking for completed games...');
    debugPrint('═══════════════════════════════════════════════════════════');

    try {
      // Get all games that might need status updates
      // (scheduled or live games from the past 24 hours)
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      final gamesSnapshot = await _firestore
          .collection('games')
          .where('status', whereIn: ['scheduled', 'live'])
          .where('gameTime', isLessThan: Timestamp.fromDate(now))
          .where('gameTime', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      if (gamesSnapshot.docs.isEmpty) {
        debugPrint('✅ [GAME STATUS UPDATER] No active games to check');
        return;
      }

      debugPrint('📊 [GAME STATUS UPDATER] Found ${gamesSnapshot.docs.length} games to check');

      // Group games by sport for efficient ESPN API queries
      final gamesBySport = <String, List<Map<String, dynamic>>>{};
      for (final doc in gamesSnapshot.docs) {
        final data = doc.data();
        final sport = data['sport']?.toString().toUpperCase() ?? '';
        if (sport.isEmpty) continue;

        if (!gamesBySport.containsKey(sport)) {
          gamesBySport[sport] = [];
        }

        gamesBySport[sport]!.add({
          'id': doc.id,
          'data': data,
        });
      }

      // Update each sport
      int totalUpdated = 0;
      for (final entry in gamesBySport.entries) {
        final sport = entry.key;
        final games = entry.value;

        debugPrint('\n🏈 [GAME STATUS UPDATER] Checking ${games.length} $sport games...');
        final updated = await _updateSportGames(sport, games);
        totalUpdated += updated;
      }

      debugPrint('\n✅ [GAME STATUS UPDATER] Update complete: $totalUpdated games marked as final');
      debugPrint('═══════════════════════════════════════════════════════════\n');

    } catch (e, stackTrace) {
      debugPrint('❌ [GAME STATUS UPDATER] Error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Update games for a specific sport using ESPN API
  Future<int> _updateSportGames(String sport, List<Map<String, dynamic>> games) async {
    int updatedCount = 0;

    try {
      // Fetch latest ESPN data for the sport
      final espnEvents = await _getEspnEventsForSport(sport);
      if (espnEvents == null || espnEvents.isEmpty) {
        debugPrint('⚠️ [GAME STATUS UPDATER] No ESPN data available for $sport');
        return 0;
      }

      debugPrint('📡 [GAME STATUS UPDATER] Fetched ${espnEvents.length} ESPN events for $sport');

      // Check each game against ESPN data
      for (final game in games) {
        final gameId = game['id'] as String;
        final gameData = game['data'] as Map<String, dynamic>;
        final espnId = gameData['espnId']?.toString();
        final homeTeam = gameData['homeTeam']?.toString() ?? '';
        final awayTeam = gameData['awayTeam']?.toString() ?? '';

        // Try to find matching ESPN event
        Map<String, dynamic>? matchingEvent;

        // First, try matching by ESPN ID if available
        if (espnId != null && espnId.isNotEmpty) {
          matchingEvent = espnEvents.firstWhere(
            (event) => event['id']?.toString() == espnId,
            orElse: () => {},
          );
          if (matchingEvent.isEmpty) matchingEvent = null;
        }

        // If no ESPN ID match, try matching by team names
        if (matchingEvent == null) {
          matchingEvent = _findEventByTeams(espnEvents, homeTeam, awayTeam);
        }

        if (matchingEvent == null) {
          debugPrint('⚠️ [GAME STATUS UPDATER] Could not find ESPN data for: $awayTeam @ $homeTeam');
          continue;
        }

        // Check ESPN status
        final competition = matchingEvent['competitions']?[0];
        if (competition == null) continue;

        final espnStatus = competition['status']?['type']?['name']?.toString() ?? '';
        final isCompleted = competition['status']?['type']?['completed'] == true;
        final isFinal = espnStatus.toLowerCase().contains('final') || isCompleted;

        if (isFinal) {
          // Game is complete! Update Firestore
          debugPrint('🎯 [GAME STATUS UPDATER] Game completed: $awayTeam @ $homeTeam');

          // Get scores
          final competitors = competition['competitors'] ?? [];
          int? homeScore;
          int? awayScore;

          for (final competitor in competitors) {
            final isHome = competitor['homeAway'] == 'home';
            final score = int.tryParse(competitor['score']?.toString() ?? '0');

            if (isHome) {
              homeScore = score;
            } else {
              awayScore = score;
            }
          }

          // Update game in Firestore
          await _firestore.collection('games').doc(gameId).update({
            'status': 'final',
            'homeScore': homeScore,
            'awayScore': awayScore,
            'completedAt': FieldValue.serverTimestamp(),
            'lastStatusCheck': FieldValue.serverTimestamp(),
          });

          debugPrint('   ✅ Updated to final - Score: $awayScore - $homeScore');
          debugPrint('   🎰 This should trigger bet settlement Cloud Function');
          updatedCount++;
        } else {
          // Game still in progress or not started
          debugPrint('   ⏳ Game not finished yet: $awayTeam @ $homeTeam (status: $espnStatus)');

          // Update last check timestamp so we know we checked it
          await _firestore.collection('games').doc(gameId).update({
            'lastStatusCheck': FieldValue.serverTimestamp(),
          });
        }
      }

    } catch (e, stackTrace) {
      debugPrint('❌ [GAME STATUS UPDATER] Error updating $sport games: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return updatedCount;
  }

  /// Get ESPN events for a specific sport
  Future<List<Map<String, dynamic>>?> _getEspnEventsForSport(String sport) async {
    try {
      switch (sport.toUpperCase()) {
        case 'NFL':
        case 'FOOTBALL':
          final scoreboard = await _nflService.getGamesForDateRange(daysAhead: 1);
          return scoreboard?.events.cast<Map<String, dynamic>>();

        case 'NBA':
        case 'BASKETBALL':
          final scoreboard = await _nbaService.getGamesForDateRange(daysAhead: 1);
          return scoreboard?.events.cast<Map<String, dynamic>>();

        case 'NHL':
        case 'HOCKEY':
          final scoreboard = await _nhlService.getGamesForDateRange(daysAhead: 1);
          return scoreboard?.events.cast<Map<String, dynamic>>();

        case 'MLB':
        case 'BASEBALL':
          final scoreboard = await _mlbService.getGamesForDateRange(daysAhead: 1);
          return scoreboard?.events.cast<Map<String, dynamic>>();

        default:
          debugPrint('⚠️ [GAME STATUS UPDATER] Unsupported sport: $sport');
          return null;
      }
    } catch (e) {
      debugPrint('❌ [GAME STATUS UPDATER] Error fetching ESPN data for $sport: $e');
      return null;
    }
  }

  /// Find ESPN event by matching team names
  Map<String, dynamic>? _findEventByTeams(
    List<Map<String, dynamic>> events,
    String homeTeam,
    String awayTeam,
  ) {
    for (final event in events) {
      final competition = event['competitions']?[0];
      if (competition == null) continue;

      final competitors = competition['competitors'] ?? [];
      if (competitors.length < 2) continue;

      String? eventHomeTeam;
      String? eventAwayTeam;

      for (final competitor in competitors) {
        final teamName = competitor['team']?['displayName']?.toString() ?? '';
        if (competitor['homeAway'] == 'home') {
          eventHomeTeam = teamName;
        } else {
          eventAwayTeam = teamName;
        }
      }

      // Check if teams match (case-insensitive)
      if (eventHomeTeam != null && eventAwayTeam != null) {
        if (_teamsMatch(homeTeam, eventHomeTeam) && _teamsMatch(awayTeam, eventAwayTeam)) {
          return event;
        }
      }
    }

    return null;
  }

  /// Check if two team names match (handles variations)
  bool _teamsMatch(String team1, String team2) {
    final t1 = team1.toLowerCase().trim();
    final t2 = team2.toLowerCase().trim();

    // Exact match
    if (t1 == t2) return true;

    // Contains match (handles "LA Lakers" vs "Lakers")
    if (t1.contains(t2) || t2.contains(t1)) return true;

    // Split and check last word (team name)
    final t1Parts = t1.split(' ');
    final t2Parts = t2.split(' ');
    if (t1Parts.isNotEmpty && t2Parts.isNotEmpty) {
      if (t1Parts.last == t2Parts.last) return true;
    }

    return false;
  }

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
