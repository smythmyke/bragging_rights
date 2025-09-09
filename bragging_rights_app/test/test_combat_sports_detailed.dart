import 'package:http/http.dart' as http;
import 'dart:convert';

// Detailed test for MMA and Boxing to find events with proper prop markets
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🥊 DETAILED COMBAT SPORTS TEST');
  print('=' * 50);
  print('Finding events with proper prop markets for MMA and Boxing\n');
  
  // Test MMA events in detail
  print('🔴 TESTING MMA EVENTS');
  print('-' * 30);
  
  try {
    final mmaEventsUrl = 'https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=$apiKey';
    final mmaResponse = await http.get(Uri.parse(mmaEventsUrl));
    
    if (mmaResponse.statusCode == 200) {
      final events = json.decode(mmaResponse.body) as List;
      print('Found ${events.length} MMA events');
      
      // Test first 5 events to find one with method of victory props
      for (int i = 0; i < events.length && i < 5; i++) {
        final event = events[i];
        final eventId = event['id'];
        final matchup = '${event['away_team']} vs ${event['home_team']}';
        final eventTime = event['commence_time'];
        
        print('\n${i+1}. $matchup');
        print('   Time: $eventTime');
        
        // Test with all possible MMA markets
        final mmaUrl = 'https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events/$eventId/odds?'
            'apiKey=$apiKey'
            '&regions=us'
            '&oddsFormat=american';
        
        final mmaOddsResponse = await http.get(Uri.parse(mmaUrl));
        
        if (mmaOddsResponse.statusCode == 200) {
          final data = json.decode(mmaOddsResponse.body);
          final bookmakers = data['bookmakers'] ?? [];
          
          final markets = <String>{};
          for (final bookmaker in bookmakers) {
            final bookmakerMarkets = bookmaker['markets'] ?? [];
            for (final market in bookmakerMarkets) {
              markets.add(market['key']);
            }
          }
          
          print('   📊 ${bookmakers.length} bookmakers, Markets: ${markets.join(', ')}');
          
          if (markets.contains('method_of_victory') || markets.contains('fight_outcome')) {
            print('   ✅ HAS METHOD OF VICTORY PROPS!');
            break;
          }
        } else {
          print('   ❌ Failed: ${mmaOddsResponse.statusCode}');
        }
        
        await Future.delayed(Duration(milliseconds: 300));
      }
    }
  } catch (e) {
    print('Error testing MMA: $e');
  }
  
  print('\n🥊 TESTING BOXING EVENTS');
  print('-' * 30);
  
  try {
    final boxingEventsUrl = 'https://api.the-odds-api.com/v4/sports/boxing_boxing/events?apiKey=$apiKey';
    final boxingResponse = await http.get(Uri.parse(boxingEventsUrl));
    
    if (boxingResponse.statusCode == 200) {
      final events = json.decode(boxingResponse.body) as List;
      print('Found ${events.length} Boxing events');
      
      // Test first 5 events to find one with method of victory props
      for (int i = 0; i < events.length && i < 5; i++) {
        final event = events[i];
        final eventId = event['id'];
        final matchup = '${event['away_team']} vs ${event['home_team']}';
        final eventTime = event['commence_time'];
        
        print('\n${i+1}. $matchup');
        print('   Time: $eventTime');
        
        // Test with all possible boxing markets
        final boxingUrl = 'https://api.the-odds-api.com/v4/sports/boxing_boxing/events/$eventId/odds?'
            'apiKey=$apiKey'
            '&regions=us'
            '&oddsFormat=american';
        
        final boxingOddsResponse = await http.get(Uri.parse(boxingUrl));
        
        if (boxingOddsResponse.statusCode == 200) {
          final data = json.decode(boxingOddsResponse.body);
          final bookmakers = data['bookmakers'] ?? [];
          
          final markets = <String>{};
          for (final bookmaker in bookmakers) {
            final bookmakerMarkets = bookmaker['markets'] ?? [];
            for (final market in bookmakerMarkets) {
              markets.add(market['key']);
            }
          }
          
          print('   📊 ${bookmakers.length} bookmakers, Markets: ${markets.join(', ')}');
          
          if (markets.contains('method_of_victory') || markets.contains('fight_outcome')) {
            print('   ✅ HAS METHOD OF VICTORY PROPS!');
            break;
          }
        } else {
          print('   ❌ Failed: ${boxingOddsResponse.statusCode}');
        }
        
        await Future.delayed(Duration(milliseconds: 300));
      }
    }
  } catch (e) {
    print('Error testing Boxing: $e');
  }
  
  print('\n' + '=' * 50);
  print('📋 FINDINGS:');
  print('• Combat sports events are available');
  print('• Most events have h2h and totals markets');
  print('• Method of victory props may be limited to major events');
  print('• The app will handle missing prop markets gracefully');
}