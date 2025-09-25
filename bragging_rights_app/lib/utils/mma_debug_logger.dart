import '../models/mma_event_model.dart';
import '../models/game_model.dart';

class MMADebugLogger {
  static final String _separator = '=' * 60;
  static final String _subSeparator = '-' * 40;

  // Event structure logging
  static void logEventStructure(MMAEvent event, {String? context}) {
    print(_separator);
    print('🥊 MMA EVENT STRUCTURE DEBUG');
    if (context != null) print('📍 Context: $context');
    print('Event ID: ${event.id}');
    print('Event Name: ${event.name}');
    print('Short Name: ${event.shortName}');
    print('Promotion: ${event.promotion}');
    print('Date: ${event.date}');
    print('Total Fights: ${event.fights.length}');
    print('Main Event ID: ${event.mainEvent?.id}');
    print('Co-Main Event ID: ${event.coMainEvent?.id}');

    print('\n📋 FIGHT CARD ORDER:');
    print(_subSeparator);

    // Group fights by card position
    final mainCard = event.fights.where((f) => f.cardPosition == 'main').toList();
    final prelims = event.fights.where((f) => f.cardPosition == 'prelim').toList();
    final earlyPrelims = event.fights.where((f) => f.cardPosition == 'early').toList();

    if (mainCard.isNotEmpty) {
      print('MAIN CARD (${mainCard.length} fights):');
      _logFightsList(mainCard);
    }

    if (prelims.isNotEmpty) {
      print('\nPRELIMINARY CARD (${prelims.length} fights):');
      _logFightsList(prelims);
    }

    if (earlyPrelims.isNotEmpty) {
      print('\nEARLY PRELIMS (${earlyPrelims.length} fights):');
      _logFightsList(earlyPrelims);
    }

    // Broadcast info
    print('\n📺 BROADCAST INFO:');
    print('Broadcasters: ${event.broadcasters?.join(', ') ?? 'None'}');
    print('Broadcast by card: ${event.broadcastByCard}');

    print(_separator);
  }

  static void _logFightsList(List<MMAFight> fights) {
    fights.asMap().forEach((index, fight) {
      final fighter1 = fight.fighter1?.name ?? 'TBD';
      final fighter2 = fight.fighter2?.name ?? 'TBD';
      final badges = <String>[];

      if (fight.isMainEvent) badges.add('👑 MAIN EVENT');
      if (fight.isCoMainEvent) badges.add('🥈 CO-MAIN');
      if (fight.isTitleFight) badges.add('🏆 TITLE');

      print('  [$index] $fighter1 vs $fighter2');
      print('       Weight: ${fight.weightClass ?? 'Unknown'}');
      print('       Rounds: ${fight.rounds}');
      if (badges.isNotEmpty) {
        print('       Badges: ${badges.join(', ')}');
      }
      print('       Fight Order: ${fight.fightOrder}');
      print('       Card Position: ${fight.cardPosition}');
    });
  }

  // Game model creation logging
  static void logGameModelCreation(GameModel game, {String? source}) {
    print(_separator);
    print('🎮 GAME MODEL CREATION');
    if (source != null) print('📍 Source: $source');
    print('Game ID: ${game.id}');
    print('Sport: ${game.sport}');
    print('Home Team (Fighter 1): ${game.homeTeam}');
    print('Away Team (Fighter 2): ${game.awayTeam}');
    print('Event Name: ${game.eventName}');
    print('Main Event Fighters: ${game.mainEventFighters}');
    print('Total Fights: ${game.totalFights ?? 0}');
    print('Has Fights List: ${game.fights != null ? game.fights!.length : 0} fights');
    print(_separator);
  }

  // API response logging
  static void logAPIResponse(Map<String, dynamic> response, {String? endpoint}) {
    print(_separator);
    print('🌐 API RESPONSE DEBUG');
    if (endpoint != null) print('📍 Endpoint: $endpoint');

    // Log key fields without dumping entire response
    print('Response Keys: ${response.keys.join(', ')}');

    if (response.containsKey('competitions')) {
      final competitions = response['competitions'] as List?;
      print('Competitions Count: ${competitions?.length ?? 0}');

      if (competitions != null && competitions.isNotEmpty) {
        final first = competitions.first;
        print('First Competition:');
        print('  - ID: ${first['id']}');
        print('  - Name: ${first['name'] ?? 'N/A'}');
        print('  - Type: ${first['type']?['text'] ?? 'N/A'}');
        print('  - Status: ${first['status']?['type']?['description'] ?? 'N/A'}');
      }
    }

    if (response.containsKey('name')) {
      print('Event Name from API: ${response['name']}');
    }

    print(_separator);
  }

  // Event grouping logging
  static void logEventGrouping(List<GameModel> games, {String? windowName}) {
    print(_separator);
    print('📦 EVENT GROUPING DEBUG');
    if (windowName != null) print('📍 Window: $windowName');
    print('Total games in group: ${games.length}');

    for (var game in games) {
      print('\n  Game: ${game.homeTeam} vs ${game.awayTeam}');
      print('    - Game ID: ${game.id}');
      print('    - Event Name: ${game.eventName}');
      print('    - Time: ${game.gameTime}');
      print('    - Is Main Event: ${game.mainEventFighters?.contains(game.homeTeam) ?? false}');
    }

    print(_separator);
  }

  // Main event selection logging
  static void logMainEventSelection(List<GameModel> candidates, GameModel? selected) {
    print(_separator);
    print('👑 MAIN EVENT SELECTION DEBUG');
    print('Candidates: ${candidates.length}');

    for (var i = 0; i < candidates.length; i++) {
      final game = candidates[i];
      final isSelected = selected?.id == game.id;
      final prefix = isSelected ? '✅' : '  ';

      print('$prefix [$i] ${game.homeTeam} vs ${game.awayTeam}');
      // Note: isMainEvent and fightOrder are not in GameModel
      // These would need to be checked in the fights list
      print('       - Main event fighters: ${game.mainEventFighters}');
    }

    if (selected != null) {
      print('\n🎯 SELECTED: ${selected.homeTeam} vs ${selected.awayTeam}');
      print('   Reason: ${_getSelectionReason(candidates, selected)}');
    } else {
      print('⚠️ WARNING: No main event selected!');
    }

    print(_separator);
  }

  static String _getSelectionReason(List<GameModel> candidates, GameModel selected) {
    // Check if it's the last fight (typical main event position)
    if (candidates.last.id == selected.id) return 'Last fight in list (typical main event position)';
    if (candidates.first.id == selected.id) return 'First fight (highest importance score or fallback)';
    return 'Selected based on importance scoring';
  }

  // Navigation logging
  static void logNavigation(String route, Map<String, dynamic> arguments) {
    print(_separator);
    print('🚀 NAVIGATION DEBUG');
    print('Route: $route');
    print('Arguments:');
    arguments.forEach((key, value) {
      if (value is List) {
        print('  $key: List with ${value.length} items');
      } else if (value is Map) {
        print('  $key: Map with keys: ${value.keys.join(', ')}');
      } else {
        print('  $key: $value');
      }
    });
    print(_separator);
  }

  // Warning logger
  static void logWarning(String message, {Map<String, dynamic>? details}) {
    print(_separator);
    print('⚠️ WARNING: $message');
    if (details != null) {
      print('Details:');
      details.forEach((key, value) {
        print('  $key: $value');
      });
    }
    print(_separator);
  }

  // Error logger
  static void logError(String message, {dynamic error, StackTrace? stackTrace}) {
    print(_separator);
    print('❌ ERROR: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace:\n$stackTrace');
    }
    print(_separator);
  }
}