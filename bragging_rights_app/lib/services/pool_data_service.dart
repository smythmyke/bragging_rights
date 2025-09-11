import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pool_model.dart';

class PoolDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get user's active pools
  Future<List<Map<String, dynamic>>> getUserActivePools() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      // First get pool IDs the user has joined
      final userPoolsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('pools')
          .get();
      
      if (userPoolsDoc.docs.isEmpty) return [];
      
      // Then fetch the actual pool data
      final poolIds = userPoolsDoc.docs.map((doc) => doc.id).toList();
      final pools = <Map<String, dynamic>>[];
      
      for (final poolId in poolIds) {
        final poolDoc = await _firestore
            .collection('pools')
            .doc(poolId)
            .get();
        
        if (poolDoc.exists) {
          final data = poolDoc.data()!;
          pools.add({
            'id': poolDoc.id,
            'name': data['name'] ?? 'Unnamed Pool',
            'buyIn': data['buyIn'] ?? 0,
            'currentPlayers': data['currentPlayers'] ?? 0,
            'maxPlayers': data['maxPlayers'] ?? 0,
            'sport': data['sport'] ?? 'General',
            'isLive': data['status'] == 'active',
            'prizePool': data['prizePool'] ?? 0,
          });
        }
      }
      
      return pools;
    } catch (e) {
      print('Error fetching user pools: $e');
      return [];
    }
  }
  
  // Get pools created by the user
  Future<List<Map<String, dynamic>>> getUserCreatedPools() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection('pools')
          .where('createdBy', isEqualTo: userId)
          .where('status', whereIn: ['open', 'active'])
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Pool',
          'buyIn': data['buyIn'] ?? 0,
          'currentPlayers': data['currentPlayers'] ?? 0,
          'maxPlayers': data['maxPlayers'] ?? 0,
          'sport': data['sport'] ?? 'General',
          'isLive': data['status'] == 'active',
          'prizePool': data['prizePool'] ?? 0,
          'isCreator': true,
        };
      }).toList();
    } catch (e) {
      print('Error fetching user created pools: $e');
      return [];
    }
  }
  
  // Get featured/public pools
  Future<List<Map<String, dynamic>>> getFeaturedPools() async {
    try {
      final snapshot = await _firestore
          .collection('pools')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: 'open')
          .limit(5)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Pool',
          'sport': data['sport'] ?? 'General',
          'buyIn': data['buyIn'] ?? 0,
          'currentPlayers': data['currentPlayers'] ?? 0,
          'maxPlayers': data['maxPlayers'] ?? 0,
          'prizePool': data['prizePool'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching featured pools: $e');
      return [];
    }
  }
  
  // Get pools by sport
  Future<List<Map<String, dynamic>>> getPoolsBySport(String sport) async {
    try {
      final snapshot = await _firestore
          .collection('pools')
          .where('sport', isEqualTo: sport)
          .where('status', isEqualTo: 'open')
          .limit(10)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Pool',
          'sport': data['sport'] ?? sport,
          'buyIn': data['buyIn'] ?? 0,
          'currentPlayers': data['currentPlayers'] ?? 0,
          'maxPlayers': data['maxPlayers'] ?? 0,
          'prizePool': data['prizePool'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching pools by sport: $e');
      return [];
    }
  }
  
  // Get quick join pools by buy-in range
  Future<List<Map<String, dynamic>>> getQuickJoinPools() async {
    try {
      final pools = <Map<String, dynamic>>[];
      
      // Define buy-in ranges
      final ranges = [
        {'name': 'Beginner Pool', 'min': 5, 'max': 15},
        {'name': 'Standard Pool', 'min': 20, 'max': 50},
        {'name': 'High Stakes', 'min': 75, 'max': 150},
        {'name': 'Whale Pool', 'min': 200, 'max': 1000},
      ];
      
      // Simplified query to avoid compound index requirement
      // First get all open pools, then filter by buy-in range in memory
      final snapshot = await _firestore
          .collection('pools')
          .where('status', isEqualTo: 'open')
          .get();
      
      print('Found ${snapshot.docs.length} open pools total');
      
      for (final range in ranges) {
        // Filter by buy-in range in memory
        try {
          final rangePool = snapshot.docs.firstWhere(
            (doc) {
              final buyIn = doc.data()['buyIn'] ?? 0;
              return buyIn >= range['min'] && buyIn <= range['max'];
            },
          );
          
          final data = rangePool.data();
          pools.add({
            'id': rangePool.id,
            'name': data['name'] ?? range['name'],
            'buyIn': data['buyIn'] ?? range['min'],
            'currentPlayers': data['currentPlayers'] ?? 0,
            'maxPlayers': data['maxPlayers'] ?? 0,
            'category': range['name'],
          });
        } catch (e) {
          // No pool found in this range, skip it
          print('No pool found for range: ${range['name']}');
        }
      }
      
      return pools;
    } catch (e) {
      print('Error fetching quick join pools: $e');
      return [];
    }
  }
}