import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PoolCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final PoolCleanupService _instance = PoolCleanupService._internal();
  
  factory PoolCleanupService() => _instance;
  PoolCleanupService._internal();

  /// Clean up expired and empty pools
  Future<int> cleanupExpiredPools() async {
    int deletedCount = 0;
    
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();
      
      // Query for pools to clean up
      final poolsQuery = await _firestore
          .collection('pools')
          .where('status', whereIn: ['open', 'cancelled'])
          .get();
      
      for (final poolDoc in poolsQuery.docs) {
        final data = poolDoc.data();
        bool shouldDelete = false;
        String reason = '';
        
        // Parse dates safely
        DateTime? gameTime;
        DateTime? closeTime;
        
        if (data['gameTime'] != null) {
          if (data['gameTime'] is Timestamp) {
            gameTime = (data['gameTime'] as Timestamp).toDate();
          } else if (data['gameTime'] is int) {
            gameTime = DateTime.fromMillisecondsSinceEpoch(data['gameTime']);
          }
        }
        
        if (data['closeTime'] != null) {
          if (data['closeTime'] is Timestamp) {
            closeTime = (data['closeTime'] as Timestamp).toDate();
          } else if (data['closeTime'] is int) {
            closeTime = DateTime.fromMillisecondsSinceEpoch(data['closeTime']);
          }
        }
        
        final currentPlayers = data['currentPlayers'] ?? 0;
        final status = data['status'] ?? 'unknown';
        
        // Cleanup criteria
        if (status == 'cancelled') {
          // Delete cancelled pools older than 1 hour
          if (data['cancelledAt'] != null) {
            final cancelledAt = data['cancelledAt'] is Timestamp 
              ? (data['cancelledAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['cancelledAt']);
            
            if (now.difference(cancelledAt).inHours > 1) {
              shouldDelete = true;
              reason = 'Cancelled pool older than 1 hour';
            }
          } else {
            // If no cancellation time, check if game has ended
            if (gameTime != null && now.difference(gameTime).inHours > 4) {
              shouldDelete = true;
              reason = 'Cancelled pool for ended game';
            }
          }
        } else if (status == 'open') {
          // Delete open pools with 0 players after close time
          if (currentPlayers == 0 && closeTime != null && now.isAfter(closeTime)) {
            shouldDelete = true;
            reason = 'Empty pool past close time';
          }
          
          // Delete open pools for games that have ended (4+ hours ago)
          if (gameTime != null && now.difference(gameTime).inHours > 4) {
            shouldDelete = true;
            reason = 'Pool for ended game';
          }
        }
        
        if (shouldDelete) {
          batch.delete(poolDoc.reference);
          deletedCount++;
          debugPrint('Deleting pool ${poolDoc.id}: $reason');
        }
      }
      
      // Commit the batch delete
      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('✅ Cleaned up $deletedCount expired/empty pools');
      }
      
    } catch (e) {
      debugPrint('❌ Error cleaning up pools: $e');
    }
    
    return deletedCount;
  }
  
  /// Mark a pool as processed to prevent re-cancellation
  Future<void> markPoolAsProcessed(String poolId) async {
    try {
      await _firestore.collection('pools').doc(poolId).update({
        'processedAt': FieldValue.serverTimestamp(),
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking pool as processed: $e');
    }
  }
  
  /// Clean up pools for specific game
  Future<void> cleanupGamePools(String gameId) async {
    try {
      final batch = _firestore.batch();
      
      final poolsQuery = await _firestore
          .collection('pools')
          .where('gameId', isEqualTo: gameId)
          .where('currentPlayers', isEqualTo: 0)
          .get();
      
      for (final poolDoc in poolsQuery.docs) {
        batch.delete(poolDoc.reference);
      }
      
      await batch.commit();
      debugPrint('Cleaned up empty pools for game $gameId');
      
    } catch (e) {
      debugPrint('Error cleaning game pools: $e');
    }
  }
}