import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test script to verify MMA data fetching from ESPN API
void main() async {
  print('🥊 Testing MMA Data Fetching\n');

  // UFC 311 event ID (example)
  final eventId = '401720563';
  final espnUrl = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/fightcenter/$eventId';

  print('📡 Fetching from: $espnUrl\n');

  try {
    final response = await http.get(Uri.parse(espnUrl));

    if (response.statusCode != 200) {
      print('❌ ESPN API returned ${response.statusCode}');
      return;
    }

    final data = json.decode(response.body);
    final cards = data['cards'] as List<dynamic>? ?? [];

    print('📋 Found ${cards.length} fight cards\n');

    int fightCount = 0;

    for (final card in cards) {
      final competitions = card['competitions'] as List<dynamic>? ?? [];

      for (final comp in competitions) {
        fightCount++;

        // Extract weight class
        final weightClass = comp['type']?['text'] ??
                          comp['type']?['abbreviation'] ??
                          comp['note'] ??
                          'TBD';

        // Extract fighters
        final competitors = comp['competitors'] as List<dynamic>? ?? [];
        if (competitors.length != 2) continue;

        final fighter1 = competitors[0]['athlete'] ?? {};
        final fighter2 = competitors[1]['athlete'] ?? {};

        final fighter1Name = fighter1['displayName'] ?? 'TBD';
        final fighter2Name = fighter2['displayName'] ?? 'TBD';

        final fighter1Id = fighter1['id']?.toString() ?? '';
        final fighter2Id = fighter2['id']?.toString() ?? '';

        final fighter1Record = competitors[0]['record'] ?? '';
        final fighter2Record = competitors[1]['record'] ?? '';

        print('Fight #$fightCount:');
        print('  🥊 $fighter1Name ($fighter1Record) vs $fighter2Name ($fighter2Record)');
        print('  ⚖️ Weight Class: $weightClass');
        print('  🖼️ Fighter 1 Image: ${fighter1Id.isNotEmpty ? "https://a.espncdn.com/i/headshots/mma/players/full/$fighter1Id.png" : "N/A"}');
        print('  🖼️ Fighter 2 Image: ${fighter2Id.isNotEmpty ? "https://a.espncdn.com/i/headshots/mma/players/full/$fighter2Id.png" : "N/A"}');
        print('  📍 Card Position: ${comp['orderDetails']?['isMainCard'] == true ? "Main Card" : "Prelims"}');
        print('  📊 Fight Order: ${comp['orderDetails']?['order'] ?? 999}');
        print('');
      }
    }

    print('✅ Successfully fetched and parsed $fightCount fights');

  } catch (e) {
    print('❌ Error: $e');
  }
}