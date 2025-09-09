import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  final url = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events?apiKey=$apiKey';
  final response = await http.get(Uri.parse(url));
  final events = json.decode(response.body) as List;
  
  print('Current NFL Games from Odds API:');
  print('=' * 50);
  for (final event in events) {
    final commence = DateTime.parse(event['commence_time']);
    print('• ${event['away_team']} @ ${event['home_team']}');
    print('  ID: ${event['id']}');
    print('  Date: ${commence.toLocal()}');
    print('');
  }
  print('Total: ${events.length} games');
}