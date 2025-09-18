import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/boxing_event_model.dart';

class ESPNBoxingService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';
  static const String boxingPath = '/combatsports/boxing';
  static const String mmaPath = '/mma';

  Future<List<BoxingEvent>> getBoxingEvents() async {
    try {
      // Try boxing endpoint first
      var events = await _fetchEvents('$baseUrl$boxingPath/scoreboard');

      // If no boxing events, check MMA for boxing fights
      if (events.isEmpty) {
        events = await _fetchEvents('$baseUrl$mmaPath/scoreboard');
        // Filter for boxing events only
        events = events.where((e) =>
          e.title.toLowerCase().contains('boxing') ||
          e.promotion.toLowerCase().contains('boxing')
        ).toList();
      }

      return events;
    } catch (e) {
      print('ESPN Boxing API error: $e');
      return [];
    }
  }

  Future<List<BoxingEvent>> _fetchEvents(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        return events
            .map((e) => BoxingEvent.fromESPN(e))
            .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 1))))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching from $url: $e');
      return [];
    }
  }

  Future<BoxingEvent?> getEventDetails(String eventId) async {
    try {
      // Try boxing endpoint
      var event = await _fetchEventDetails(
        '$baseUrl$boxingPath/summary',
        eventId
      );

      // If not found, try MMA endpoint
      if (event == null) {
        event = await _fetchEventDetails(
          '$baseUrl$mmaPath/summary',
          eventId
        );
      }

      return event;
    } catch (e) {
      print('ESPN event details error: $e');
      return null;
    }
  }

  Future<BoxingEvent?> _fetchEventDetails(String baseUrl, String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?event=$eventId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['event'] != null) {
          return BoxingEvent.fromESPN(data['event']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching event details from $baseUrl: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFighterInfo(String fighterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$mmaPath/athletes/$fighterId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('ESPN fighter info error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentResults() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$boxingPath/scoreboard?dates=last7days'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        return events.where((e) {
          final status = e['competitions']?[0]?['status']?['type']?['completed'];
          return status == true;
        }).toList().cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('ESPN recent results error: $e');
      return [];
    }
  }

  // Helper method to check if ESPN has data for a specific date
  Future<bool> hasEventsForDate(DateTime date) async {
    try {
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final response = await http.get(
        Uri.parse('$baseUrl$boxingPath/scoreboard?dates=$dateStr'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];
        return events.isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}