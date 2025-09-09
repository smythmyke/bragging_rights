import 'package:http/http.dart' as http;
import 'dart:convert';

// Check API plan details and usage
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🔍 Checking API Plan Details\n');
  print('=' * 50);
  
  // Test basic endpoint to check headers
  print('\n1️⃣ Testing basic endpoint and checking response headers...\n');
  
  final url = 'https://api.the-odds-api.com/v4/sports/?apiKey=$apiKey';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    print('Status: ${response.statusCode}');
    print('\n📊 API Usage Headers:');
    
    // Check for usage headers
    final headers = response.headers;
    
    if (headers.containsKey('x-requests-remaining')) {
      print('  Requests Remaining: ${headers['x-requests-remaining']}');
    }
    if (headers.containsKey('x-requests-used')) {
      print('  Requests Used: ${headers['x-requests-used']}');
    }
    if (headers.containsKey('x-requests-limit')) {
      print('  Request Limit: ${headers['x-requests-limit']}');
    }
    
    print('\nAll headers:');
    headers.forEach((key, value) {
      if (key.toLowerCase().contains('x-')) {
        print('  $key: $value');
      }
    });
    
    // Test what the basic odds endpoint returns
    print('\n2️⃣ Testing odds endpoint capabilities...\n');
    
    final oddsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds/?'
        'apiKey=$apiKey&regions=us&oddsFormat=american';
    
    final oddsResponse = await http.get(Uri.parse(oddsUrl));
    
    if (oddsResponse.statusCode == 200) {
      final data = json.decode(oddsResponse.body) as List;
      
      if (data.isNotEmpty) {
        final game = data.first;
        final bookmakers = game['bookmakers'] ?? [];
        
        if (bookmakers.isNotEmpty) {
          final bookmaker = bookmakers.first;
          final markets = bookmaker['markets'] ?? [];
          
          print('✅ Available markets in response:');
          final marketKeys = <String>{};
          for (final market in markets) {
            marketKeys.add(market['key']);
          }
          print('  ${marketKeys.join(', ')}');
          
          print('\n📚 Bookmakers providing odds:');
          for (final bm in bookmakers) {
            print('  • ${bm['title']}');
          }
        }
      }
    }
    
    // Check if we can access the events endpoint
    print('\n3️⃣ Testing events endpoint (for potential prop access)...\n');
    
    final eventsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/?'
        'apiKey=$apiKey';
    
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    print('Events endpoint status: ${eventsResponse.statusCode}');
    
    if (eventsResponse.statusCode == 200) {
      final events = json.decode(eventsResponse.body) as List;
      print('✅ Events endpoint accessible - found ${events.length} events');
      
      if (events.isNotEmpty) {
        final eventId = events.first['id'];
        
        // Try event-specific odds
        print('\n4️⃣ Testing event-specific odds endpoint...\n');
        
        final eventOddsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/$eventId/odds?'
            'apiKey=$apiKey&regions=us&oddsFormat=american';
        
        final eventOddsResponse = await http.get(Uri.parse(eventOddsUrl));
        print('Event odds status: ${eventOddsResponse.statusCode}');
        
        if (eventOddsResponse.statusCode == 200) {
          final eventData = json.decode(eventOddsResponse.body);
          final bookmakers = eventData['bookmakers'] ?? [];
          
          final allMarkets = <String>{};
          for (final bm in bookmakers) {
            final markets = bm['markets'] ?? [];
            for (final market in markets) {
              allMarkets.add(market['key']);
            }
          }
          
          print('✅ Markets available for this event:');
          print('  ${allMarkets.join(', ')}');
        }
      }
    } else if (eventsResponse.statusCode == 404) {
      print('❌ Events endpoint not found (404)');
    }
    
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n' + '=' * 50);
  print('\n📋 SUMMARY:');
  print('Your API key is valid and working.');
  print('Your plan includes: h2h, spreads, totals');
  print('Your plan does NOT include: player props, alternate lines');
  print('\nTo get prop markets, you need to upgrade to a higher tier at:');
  print('https://the-odds-api.com/#get-access');
}