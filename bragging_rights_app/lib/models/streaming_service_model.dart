class StreamingService {
  final String name;
  final String url;
  final String? description;
  final bool isOfficial;
  final String? mirrorNumber;
  final List<String>? sports;
  final String? cost;

  StreamingService({
    required this.name,
    required this.url,
    this.description,
    required this.isOfficial,
    this.mirrorNumber,
    this.sports,
    this.cost,
  });
}

class StreamingServiceData {
  static List<StreamingService> officialServices = [
    StreamingService(
      name: 'ESPN+',
      url: 'https://www.espn.com/espnplus/',
      description: 'NFL, NHL, MLB, UFC, Boxing',
      isOfficial: true,
      sports: ['NFL', 'NHL', 'MLB', 'UFC', 'Boxing'],
      cost: '\$10.99/month',
    ),
    StreamingService(
      name: 'DAZN',
      url: 'https://www.dazn.com/',
      description: 'Boxing, MMA, Soccer',
      isOfficial: true,
      sports: ['Boxing', 'MMA', 'Soccer'],
      cost: '\$19.99/month',
    ),
    StreamingService(
      name: 'Peacock',
      url: 'https://www.peacocktv.com/',
      description: 'Premier League, NFL, WWE',
      isOfficial: true,
      sports: ['Soccer', 'NFL', 'WWE'],
      cost: '\$5.99/month',
    ),
    StreamingService(
      name: 'Amazon Prime Video',
      url: 'https://www.amazon.com/prime',
      description: 'Thursday Night Football',
      isOfficial: true,
      sports: ['NFL'],
      cost: '\$14.99/month',
    ),
    StreamingService(
      name: 'Apple TV+',
      url: 'https://www.apple.com/apple-tv-plus/',
      description: 'MLS, MLB Friday Night',
      isOfficial: true,
      sports: ['Soccer', 'MLB'],
      cost: '\$9.99/month',
    ),
    StreamingService(
      name: 'NBA League Pass',
      url: 'https://www.nba.com/watch/league-pass',
      description: 'All NBA Games',
      isOfficial: true,
      sports: ['NBA'],
      cost: '\$14.99/month',
    ),
    StreamingService(
      name: 'NHL.TV',
      url: 'https://www.nhl.com/tv',
      description: 'All NHL Games',
      isOfficial: true,
      sports: ['NHL'],
      cost: 'Included with ESPN+',
    ),
    StreamingService(
      name: 'NFL Sunday Ticket',
      url: 'https://www.youtube.com/tv',
      description: 'All Sunday NFL Games',
      isOfficial: true,
      sports: ['NFL'],
      cost: '\$349/season',
    ),
    StreamingService(
      name: 'MLB.TV',
      url: 'https://www.mlb.com/tv',
      description: 'All MLB Games',
      isOfficial: true,
      sports: ['MLB'],
      cost: '\$149.99/season',
    ),
  ];

  static List<StreamingService> thirdPartyServices = [
    // SportSurge
    StreamingService(
      name: 'SportSurge',
      url: 'https://v2.sportsurge.net/home5/',
      isOfficial: false,
      mirrorNumber: '1',
    ),
    StreamingService(
      name: 'SportSurge',
      url: 'https://sportsurge.bz/',
      isOfficial: false,
      mirrorNumber: '2',
    ),
    StreamingService(
      name: 'SportSurge',
      url: 'https://www.sportsurge.uno/',
      isOfficial: false,
      mirrorNumber: '3',
    ),
    // CrackStreams
    StreamingService(
      name: 'CrackStreams',
      url: 'https://crackstreams.cx/',
      isOfficial: false,
      mirrorNumber: '1',
    ),
    StreamingService(
      name: 'CrackStreams',
      url: 'https://crackstreams.ch/',
      isOfficial: false,
      mirrorNumber: '2',
    ),
    // BuffStreams
    StreamingService(
      name: 'BuffStreams',
      url: 'https://buffsports.io/',
      isOfficial: false,
    ),
    // LiveTV
    StreamingService(
      name: 'LiveTV',
      url: 'https://livetv860.me/enx/',
      isOfficial: false,
      mirrorNumber: '1',
    ),
    StreamingService(
      name: 'LiveTV',
      url: 'https://livetv.sx/enx/',
      isOfficial: false,
      mirrorNumber: '2',
    ),
    // DofuStream
    StreamingService(
      name: 'DofuStream',
      url: 'http://www.dofustream.com/',
      isOfficial: false,
      description: 'Main Site/App Link Hub',
    ),
    // StreamEast
    StreamingService(
      name: 'StreamEast',
      url: 'https://v2.streameast.sk/',
      isOfficial: false,
    ),
  ];
}