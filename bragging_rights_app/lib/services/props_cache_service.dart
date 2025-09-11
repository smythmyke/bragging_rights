import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/props_models.dart';

/// Service for caching props data in Firestore to minimize API calls
class PropsCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Cache TTL in minutes
  static const int _liveCacheTTL = 5; // 5 minutes for live games
  static const int _futureCacheTTL = 30; // 30 minutes for future games
  
  /// Get cached props data for an event
  Future<PropsTabData?> getCachedProps(String eventId) async {
    try {
      final doc = await _firestore
          .collection('props_cache')
          .doc(eventId)
          .get();
      
      if (!doc.exists) {
        print('[PropsCache] No cached data for event: $eventId');
        return null;
      }
      
      final data = doc.data()!;
      final metadata = data['metadata'] as Map<String, dynamic>;
      final timestamp = (metadata['timestamp'] as Timestamp).toDate();
      
      // Check if cache is still valid
      if (!_isCacheValid(timestamp, metadata['isLive'] ?? false)) {
        print('[PropsCache] Cache expired for event: $eventId');
        await _clearCache(eventId);
        return null;
      }
      
      // Reconstruct PropsTabData
      return _reconstructPropsData(eventId, data);
    } catch (e) {
      print('[PropsCache] Error getting cached props: $e');
      return null;
    }
  }
  
  /// Cache props data for an event
  Future<void> cacheProps(String eventId, PropsTabData propsData, bool isLive) async {
    try {
      // Prepare data for Firestore
      final cacheData = {
        'metadata': {
          'timestamp': FieldValue.serverTimestamp(),
          'homeTeam': propsData.homeTeam,
          'awayTeam': propsData.awayTeam,
          'isLive': isLive,
          'playerCount': propsData.playersByName.length,
        },
        'players': _serializePlayers(propsData.playersByName),
        'positions': propsData.playersByPosition,
        'teams': propsData.playersByTeam,
        'starPlayers': propsData.starPlayers,
      };
      
      await _firestore
          .collection('props_cache')
          .doc(eventId)
          .set(cacheData);
      
      print('[PropsCache] Cached props for event: $eventId (${propsData.playersByName.length} players)');
    } catch (e) {
      print('[PropsCache] Error caching props: $e');
    }
  }
  
  /// Clear cache for a specific event
  Future<void> clearCache(String eventId) async {
    try {
      await _firestore
          .collection('props_cache')
          .doc(eventId)
          .delete();
      print('[PropsCache] Cleared cache for event: $eventId');
    } catch (e) {
      print('[PropsCache] Error clearing cache: $e');
    }
  }
  
  /// Clear all old cache entries (LRU eviction)
  Future<void> clearOldCache({int maxEntries = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('props_cache')
          .orderBy('metadata.timestamp', descending: true)
          .get();
      
      if (snapshot.docs.length <= maxEntries) return;
      
      // Delete oldest entries beyond maxEntries
      final toDelete = snapshot.docs.skip(maxEntries);
      final batch = _firestore.batch();
      
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('[PropsCache] Cleared ${toDelete.length} old cache entries');
    } catch (e) {
      print('[PropsCache] Error clearing old cache: $e');
    }
  }
  
  /// Check if cache is still valid based on timestamp and game status
  bool _isCacheValid(DateTime timestamp, bool isLive) {
    final now = DateTime.now();
    final difference = now.difference(timestamp).inMinutes;
    final ttl = isLive ? _liveCacheTTL : _futureCacheTTL;
    return difference < ttl;
  }
  
  /// Serialize players map for Firestore
  Map<String, dynamic> _serializePlayers(Map<String, PlayerProps> players) {
    final serialized = <String, dynamic>{};
    
    players.forEach((name, player) {
      serialized[name] = {
        'name': player.name,
        'team': player.team,
        'position': player.position,
        'isStar': player.isStar,
        'props': player.props.map((prop) => {
          'marketKey': prop.marketKey,
          'type': prop.type,
          'displayName': prop.displayName,
          'line': prop.line,
          'overOdds': prop.overOdds,
          'underOdds': prop.underOdds,
          'straightOdds': prop.straightOdds,
          'bookmaker': prop.bookmaker,
          'description': prop.description,
        }).toList(),
      };
    });
    
    return serialized;
  }
  
  /// Reconstruct PropsTabData from cached data
  PropsTabData _reconstructPropsData(String eventId, Map<String, dynamic> data) {
    final metadata = data['metadata'] as Map<String, dynamic>;
    final playersData = data['players'] as Map<String, dynamic>;
    
    // Reconstruct PlayerProps map
    final playersByName = <String, PlayerProps>{};
    
    playersData.forEach((name, playerData) {
      final pd = playerData as Map<String, dynamic>;
      final propsData = (pd['props'] as List).map((propData) {
        final p = propData as Map<String, dynamic>;
        return PropOption(
          marketKey: p['marketKey'] ?? '',
          type: p['type'] ?? '',
          displayName: p['displayName'] ?? '',
          line: p['line']?.toDouble(),
          overOdds: p['overOdds']?.toInt(),
          underOdds: p['underOdds']?.toInt(),
          straightOdds: p['straightOdds']?.toInt(),
          bookmaker: p['bookmaker'] ?? '',
          description: p['description'] ?? '',
        );
      }).toList();
      
      playersByName[name] = PlayerProps(
        name: pd['name'] ?? name,
        team: pd['team'] ?? '',
        position: pd['position'] ?? '',
        isStar: pd['isStar'] ?? false,
        props: propsData,
      );
    });
    
    // Reconstruct position and team maps
    final playersByPosition = <String, List<String>>{};
    final positionsData = data['positions'] as Map<String, dynamic>?;
    if (positionsData != null) {
      positionsData.forEach((position, players) {
        playersByPosition[position] = List<String>.from(players);
      });
    }
    
    final playersByTeam = <String, List<String>>{};
    final teamsData = data['teams'] as Map<String, dynamic>?;
    if (teamsData != null) {
      teamsData.forEach((team, players) {
        playersByTeam[team] = List<String>.from(players);
      });
    }
    
    return PropsTabData(
      homeTeam: metadata['homeTeam'] ?? '',
      awayTeam: metadata['awayTeam'] ?? '',
      playersByName: playersByName,
      starPlayers: List<String>.from(data['starPlayers'] ?? []),
      playersByPosition: playersByPosition,
      playersByTeam: playersByTeam,
      cacheTime: (metadata['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventId: eventId,
    );
  }
  
  /// Clear cache helper
  Future<void> _clearCache(String eventId) async {
    await clearCache(eventId);
  }
}