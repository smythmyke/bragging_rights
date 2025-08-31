import 'bragging_rights_app/lib/services/espn_direct_service.dart';
import 'bragging_rights_app/lib/models/game_model.dart';

void main() async {
  print('Testing ESPN Direct Service for UFC Events...\n');
  
  final service = ESPNDirectService();
  
  // Test fetching UFC games specifically
  print('1. Fetching UFC events (60 days)...');
  final ufcGames = await service.fetchSportGames('UFC');
  
  print('Found ${ufcGames.length} UFC events');
  
  for (final game in ufcGames) {
    print('\n${game.gameTime.toString().split(' ')[0]} - ${game.awayTeam} vs ${game.homeTeam}');
    print('  Status: ${game.status}');
    print('  Venue: ${game.venue ?? "TBD"}');
  }
  
  // Test fetching all games (including UFC)
  print('\n\n2. Fetching all sports including UFC...');
  final allGames = await service.fetchAllGames();
  
  final ufcFromAll = allGames.where((g) => g.sport == 'UFC').toList();
  print('UFC events in all games: ${ufcFromAll.length}');
  
  // Show combat sports summary
  final combatSports = ['UFC', 'BELLATOR', 'PFL', 'BOXING'];
  for (final sport in combatSports) {
    final count = allGames.where((g) => g.sport == sport).length;
    if (count > 0) {
      print('$sport: $count events');
    }
  }
}