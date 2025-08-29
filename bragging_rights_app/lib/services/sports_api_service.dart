import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/game_model.dart';
import '../models/odds_model.dart';

class SportsApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Fetch today's games for a specific sport
  Future<List<Game>> getTodaysGames(String sport) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: sport)
          .where('gameTime', isGreaterThanOrEqualTo: startOfDay)
          .where('gameTime', isLessThan: endOfDay)
          .orderBy('gameTime')
          .get();

      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching today\'s games: $e');
      return [];
    }
  }

  // Fetch upcoming games for a specific sport
  Future<List<Game>> getUpcomingGames(String sport, {int limit = 10}) async {
    try {
      final now = DateTime.now();
      
      final snapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: sport)
          .where('gameTime', isGreaterThanOrEqualTo: now)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('gameTime')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching upcoming games: $e');
      return [];
    }
  }

  // Fetch live games
  Future<List<Game>> getLiveGames({String? sport}) async {
    try {
      Query query = _firestore.collection('games').where('status', isEqualTo: 'live');
      
      if (sport != null) {
        query = query.where('sport', isEqualTo: sport);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching live games: $e');
      return [];
    }
  }

  // Get game details
  Future<Game?> getGameDetails(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      
      if (doc.exists) {
        return Game.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching game details: $e');
      return null;
    }
  }

  // Get odds for a specific game
  Future<OddsData?> getGameOdds(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['odds'] != null) {
          return OddsData.fromMap(data['odds']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching game odds: $e');
      return null;
    }
  }

  // Stream game updates (for live scoring)
  Stream<Game?> streamGameUpdates(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Game.fromFirestore(doc);
      }
      return null;
    });
  }

  // Trigger manual data update (calls Cloud Function)
  Future<void> triggerDataUpdate(String sport) async {
    try {
      final callable = _functions.httpsCallable('fetchLiveGames');
      await callable.call({'sport': sport});
    } catch (e) {
      print('Error triggering data update: $e');
    }
  }

  // Get all games for multiple sports
  Future<Map<String, List<Game>>> getAllSportsGames() async {
    final sports = ['NFL', 'NBA', 'MLB', 'NHL', 'MMA', 'BOXING'];
    final gamesMap = <String, List<Game>>{};
    
    for (final sport in sports) {
      gamesMap[sport] = await getTodaysGames(sport);
    }
    
    return gamesMap;
  }

  // Search games by teams
  Future<List<Game>> searchGames(String searchTerm) async {
    try {
      // Search in home team
      final homeSnapshot = await _firestore
          .collection('games')
          .where('homeTeam', isGreaterThanOrEqualTo: searchTerm)
          .where('homeTeam', isLessThan: searchTerm + '\uf8ff')
          .limit(10)
          .get();
      
      // Search in away team
      final awaySnapshot = await _firestore
          .collection('games')
          .where('awayTeam', isGreaterThanOrEqualTo: searchTerm)
          .where('awayTeam', isLessThan: searchTerm + '\uf8ff')
          .limit(10)
          .get();
      
      final games = <Game>[];
      games.addAll(homeSnapshot.docs.map((doc) => Game.fromFirestore(doc)));
      games.addAll(awaySnapshot.docs.map((doc) => Game.fromFirestore(doc)));
      
      // Remove duplicates
      final uniqueGames = <String, Game>{};
      for (final game in games) {
        uniqueGames[game.id] = game;
      }
      
      return uniqueGames.values.toList();
    } catch (e) {
      print('Error searching games: $e');
      return [];
    }
  }
}

// Game Model
class Game {
  final String id;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final DateTime gameTime;
  final String status; // scheduled, live, final
  final int? homeScore;
  final int? awayScore;
  final String? period; // quarter, half, inning, etc.
  final String? timeRemaining;
  final Map<String, dynamic>? odds;
  final String? venue;
  final String? broadcast;

  Game({
    required this.id,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.gameTime,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.period,
    this.timeRemaining,
    this.odds,
    this.venue,
    this.broadcast,
  });

  factory Game.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Game(
      id: doc.id,
      sport: data['sport'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      gameTime: (data['gameTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'scheduled',
      homeScore: data['homeScore'],
      awayScore: data['awayScore'],
      period: data['period'],
      timeRemaining: data['timeRemaining'],
      odds: data['odds'],
      venue: data['venue'],
      broadcast: data['broadcast'],
    );
  }

  String get gameTitle => '$awayTeam @ $homeTeam';
  
  bool get isLive => status == 'live';
  bool get isFinal => status == 'final';
  bool get isScheduled => status == 'scheduled';
  
  Duration get timeUntilGame => gameTime.difference(DateTime.now());
  
  // Convert to GameModel for compatibility
  GameModel toGameModel() {
    return GameModel(
      id: id,
      sport: sport,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      gameTime: gameTime,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      period: period,
      timeRemaining: timeRemaining,
      odds: odds,
      venue: venue,
      broadcast: broadcast,
    );
  }
}

// Odds Model
class OddsData {
  final double? homeMoneyline;
  final double? awayMoneyline;
  final double? spread;
  final double? spreadHomeOdds;
  final double? spreadAwayOdds;
  final double? totalPoints;
  final double? overOdds;
  final double? underOdds;
  final DateTime? lastUpdated;

  OddsData({
    this.homeMoneyline,
    this.awayMoneyline,
    this.spread,
    this.spreadHomeOdds,
    this.spreadAwayOdds,
    this.totalPoints,
    this.overOdds,
    this.underOdds,
    this.lastUpdated,
  });

  factory OddsData.fromMap(Map<String, dynamic> map) {
    return OddsData(
      homeMoneyline: map['homeMoneyline']?.toDouble(),
      awayMoneyline: map['awayMoneyline']?.toDouble(),
      spread: map['spread']?.toDouble(),
      spreadHomeOdds: map['spreadHomeOdds']?.toDouble(),
      spreadAwayOdds: map['spreadAwayOdds']?.toDouble(),
      totalPoints: map['totalPoints']?.toDouble(),
      overOdds: map['overOdds']?.toDouble(),
      underOdds: map['underOdds']?.toDouble(),
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }
  
  // Convert to OddsModel for compatibility
  OddsModel toOddsModel() {
    return OddsModel(
      homeMoneyline: homeMoneyline,
      awayMoneyline: awayMoneyline,
      spread: spread,
      spreadHomeOdds: spreadHomeOdds,
      spreadAwayOdds: spreadAwayOdds,
      totalPoints: totalPoints,
      overOdds: overOdds,
      underOdds: underOdds,
      lastUpdated: lastUpdated,
    );
  }
}