import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testLiveSports() async {
  print('\n=== TESTING LIVE SPORTS DATA ===\n');
  
  // Test each sport
  final sports = {
    'MLB': 'baseball/mlb',
    'NFL': 'football/nfl', 
    'NBA': 'basketball/nba',
    'NHL': 'hockey/nhl',
    'MMA': 'mma/ufc',
  };
  
  for (final entry in sports.entries) {
    print('Checking ${entry.key}...');
    
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/${entry.value}/scoreboard';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? [];
        
        if (events.isEmpty) {
          print('  ❌ No events found');
        } else {
          print('  ✅ Found ${events.length} events:');
          
          // Show first 3 events
          for (int i = 0; i < events.length && i < 3; i++) {
            final event = events[i];
            final date = DateTime.parse(event['date']);
            final name = event['name'];
            final status = event['status']?['type']?['description'] ?? 'Scheduled';
            
            print('     ${i+1}. $name');
            print('        Date: ${date.toLocal()}');
            print('        Status: $status');
          }
        }
      } else {
        print('  ❌ API error: ${response.statusCode}');
      }
    } catch (e) {
      print('  ❌ Error: $e');
    }
    
    print('');
  }
  
  // Check upcoming dates for sports with no current events
  print('\n=== CHECKING UPCOMING GAMES ===\n');
  
  for (final entry in sports.entries) {
    print('Checking next 7 days for ${entry.key}...');
    
    try {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateStr = '${tomorrow.year}${tomorrow.month.toString().padLeft(2, '0')}${tomorrow.day.toString().padLeft(2, '0')}';
      final url = 'https://site.api.espn.com/apis/site/v2/sports/${entry.value}/scoreboard?dates=$dateStr-${DateTime.now().add(Duration(days: 7)).year}${DateTime.now().add(Duration(days: 7)).month.toString().padLeft(2, '0')}${DateTime.now().add(Duration(days: 7)).day.toString().padLeft(2, '0')}';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? [];
        
        if (events.isNotEmpty) {
          final firstEvent = events[0];
          final date = DateTime.parse(firstEvent['date']);
          print('  ✅ Next game: ${firstEvent['name']} on ${date.toLocal()}');
        } else {
          print('  ❌ No upcoming games in next 7 days');
        }
      }
    } catch (e) {
      print('  ❌ Error checking upcoming: $e');
    }
  }
}

void main() async {
  await testLiveSports();
}