import 'package:cloud_firestore/cloud_firestore.dart';

enum DataSource { boxingData, espn }
enum EventStatus { upcoming, live, completed }

class BoxingEvent {
  final String id;
  final String title;
  final DateTime date;
  final String venue;
  final String location;
  final String? posterUrl;
  final String promotion;
  final List<String> broadcasters;
  final DataSource source;
  final bool hasFullData;
  final EventStatus status;
  final DateTime? lastUpdated;

  // Additional fields only from Boxing Data API
  final List<String>? ringAnnouncers;
  final List<String>? tvAnnouncers;
  final List<String>? coPromotions;

  BoxingEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.venue,
    required this.location,
    this.posterUrl,
    required this.promotion,
    required this.broadcasters,
    required this.source,
    required this.hasFullData,
    this.status = EventStatus.upcoming,
    this.lastUpdated,
    this.ringAnnouncers,
    this.tvAnnouncers,
    this.coPromotions,
  });

  bool get canShowFullDetails => source == DataSource.boxingData && hasFullData;

  factory BoxingEvent.fromBoxingData(Map<String, dynamic> data) {
    return BoxingEvent(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      date: _parseDate(data['date']),
      venue: data['venue'] ?? '',
      location: data['location'] ?? '',
      posterUrl: data['poster_image_url'],
      promotion: data['promotion'] ?? '',
      broadcasters: _extractBroadcasters(data['broadcasters']),
      source: DataSource.boxingData,
      hasFullData: true,
      status: _parseStatus(data['status']),
      ringAnnouncers: List<String>.from(data['ring_announcers'] ?? []),
      tvAnnouncers: List<String>.from(data['tv_announcers'] ?? []),
      coPromotions: List<String>.from(data['co_promotion'] ?? []),
      lastUpdated: data['lastUpdated'] != null
        ? (data['lastUpdated'] as Timestamp).toDate()
        : null,
    );
  }

  factory BoxingEvent.fromESPN(Map<String, dynamic> data) {
    final competition = data['competitions']?[0] ?? {};
    final venue = competition['venue'] ?? {};

    return BoxingEvent(
      id: data['id'] ?? '',
      title: data['name'] ?? data['shortName'] ?? '',
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      venue: venue['fullName'] ?? '',
      location: venue['address']?['city'] ?? '',
      posterUrl: null,
      promotion: 'Boxing',
      broadcasters: _extractESPNBroadcasters(competition['broadcasts']),
      source: DataSource.espn,
      hasFullData: false,
      status: competition['status']?['type']?['state'] == 'in'
          ? EventStatus.live
          : competition['status']?['type']?['completed'] == true
              ? EventStatus.completed
              : EventStatus.upcoming,
    );
  }

  factory BoxingEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return BoxingEvent.fromBoxingData(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'venue': venue,
      'location': location,
      'posterUrl': posterUrl,
      'promotion': promotion,
      'broadcasters': broadcasters,
      'source': source.toString(),
      'hasFullData': hasFullData,
      'status': status.toString(),
      'ringAnnouncers': ringAnnouncers,
      'tvAnnouncers': tvAnnouncers,
      'coPromotions': coPromotions,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.parse(date);
    return DateTime.now();
  }

  static EventStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'live':
      case 'in_progress':
        return EventStatus.live;
      case 'completed':
      case 'finished':
        return EventStatus.completed;
      default:
        return EventStatus.upcoming;
    }
  }

  static List<String> _extractBroadcasters(dynamic broadcasters) {
    if (broadcasters == null) return [];
    if (broadcasters is List) {
      final result = <String>[];
      for (var item in broadcasters) {
        if (item is Map) {
          item.forEach((key, value) {
            result.add('$value ($key)');
          });
        } else if (item is String) {
          result.add(item);
        }
      }
      return result;
    }
    return [];
  }

  static List<String> _extractESPNBroadcasters(dynamic broadcasts) {
    if (broadcasts == null || broadcasts is! List) return [];
    return broadcasts
        .map((b) => b['names']?.join(', ') ?? '')
        .where((s) => s.isNotEmpty)
        .toList()
        .cast<String>();
  }
}