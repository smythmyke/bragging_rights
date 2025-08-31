import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing UFC API endpoints...\n');
  
  // Test UFC scoreboard
  await testUFCScoreboard();
  
  // Test date range
  await testUFCDateRange();
}

Future<void> testUFCScoreboard() async {
  print('1. Testing UFC Scoreboard endpoint...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      print('✅ UFC Scoreboard API working');
      print('   Found ${events.length} events');
      
      for (final event in events) {
        print('   - ${event['name']} on ${event['date']}');
        
        final competitions = event['competitions'] ?? [];
        for (final comp in competitions) {
          final competitors = comp['competitors'] ?? [];
          if (competitors.length >= 2) {
            final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'TBD';
            final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'TBD';
            print('     $fighter1 vs $fighter2');
          }
        }
      }
    } else {
      print('❌ Error: Status ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching UFC data: $e');
  }
  print('');
}

Future<void> testUFCDateRange() async {
  print('2. Testing UFC Date Range endpoint...');
  
  final now = DateTime.now();
  final endDate = now.add(Duration(days: 30));
  
  final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
  
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard?dates=$startStr-$endStr'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      final calendar = data['leagues']?[0]?['calendar'] ?? [];
      
      print('✅ UFC Date Range API working');
      print('   Found ${events.length} events in next 30 days');
      print('   Calendar has ${calendar.length} scheduled events');
      
      for (final cal in calendar) {
        print('   - ${cal['label']} on ${cal['startDate']}');
      }
    } else {
      print('❌ Error: Status ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching UFC date range: $e');
  }
  print('');
}