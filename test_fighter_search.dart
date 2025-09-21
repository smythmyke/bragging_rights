import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify ESPN fighter search API
Future<void> testFighterSearch() async {
  print('🧪 Testing ESPN Fighter Search API\n');

  // Test with well-known UFC fighters
  final testFighters = [
    'Jon Jones',
    'Israel Adesanya',
    'Conor McGregor',
    'Charles Oliveira',
    'Islam Makhachev',
    'Charlie Campbell',  // The fighter from your logs
    'Tom Nolan',         // The fighter from your logs
  ];

  for (final fighterName in testFighters) {
    print('=' * 60);
    print('🔍 Searching for: $fighterName');

    try {
      // ESPN search API endpoint
      final searchUrl = 'https://site.web.api.espn.com/apis/search/v2?region=us&lang=en&section=mma&limit=5&page=1&query=${Uri.encodeComponent(fighterName)}&type=athlete';
      print('📡 URL: $searchUrl');

      final response = await http.get(Uri.parse(searchUrl));
      print('📊 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          print('✅ Found ${data['results'].length} results\n');

          // Print details of first result
          final firstResult = data['results'][0];
          print('  Fighter Details:');
          print('  - Name: ${firstResult['displayName'] ?? 'N/A'}');
          print('  - ID: ${firstResult['id'] ?? 'N/A'}');
          print('  - Type: ${firstResult['type'] ?? 'N/A'}');

          // If we found an ID, try to fetch full fighter data
          if (firstResult['id'] != null) {
            final athleteId = firstResult['id'].toString();
            print('\n  📥 Fetching full fighter data...');

            final athleteUrl = 'http://sports.core.api.espn.com/v2/sports/mma/athletes/$athleteId';
            final athleteResponse = await http.get(Uri.parse(athleteUrl));

            if (athleteResponse.statusCode == 200) {
              final athleteData = json.decode(athleteResponse.body);
              print('  ✅ Fighter data retrieved successfully');
              print('    - Full Name: ${athleteData['fullName'] ?? athleteData['displayName'] ?? 'N/A'}');
              print('    - Weight: ${athleteData['weight'] ?? 'N/A'}');
              print('    - Height: ${athleteData['height'] ?? 'N/A'}');

              // Check for image
              final headshotUrl = 'https://a.espncdn.com/i/headshots/mma/players/full/$athleteId.png';
              print('    - Image URL: $headshotUrl');

              // Test if image exists
              final imageResponse = await http.head(Uri.parse(headshotUrl));
              if (imageResponse.statusCode == 200) {
                print('    - Image: ✅ Available');
              } else {
                print('    - Image: ❌ Not found (${imageResponse.statusCode})');
              }
            } else {
              print('  ❌ Failed to fetch fighter data: ${athleteResponse.statusCode}');
            }
          }
        } else {
          print('❌ No results found for "$fighterName"');

          // Let's also check what the response structure looks like
          if (data['results'] != null) {
            print('  Results array is empty');
          }
          if (data['totalResults'] != null) {
            print('  Total results: ${data['totalResults']}');
          }
        }
      } else {
        print('❌ Search failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }

    print('');
  }

  print('=' * 60);
  print('🏁 Test completed');
}

void main() async {
  await testFighterSearch();
}