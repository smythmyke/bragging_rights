import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<FriendData>> getFriendsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      if (friendIds.isEmpty) return [];

      final friends = <FriendData>[];
      for (final friendId in friendIds) {
        final friendDoc = await _firestore
            .collection('users')
            .doc(friendId)
            .get();
        
        if (friendDoc.exists) {
          final data = friendDoc.data()!;
          friends.add(FriendData(
            id: friendId,
            username: data['username'] ?? 'Unknown',
            displayName: data['displayName'] ?? data['username'] ?? 'Unknown',
            totalProfit: (data['totalProfit'] ?? 0).toDouble(),
            winRate: (data['winRate'] ?? 0).toDouble(),
            currentStreak: data['currentStreak'] ?? 0,
            lastActive: data['lastActive']?.toDate() ?? DateTime.now(),
          ));
        }
      }

      friends.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
      return friends;
    });
  }

  Stream<FriendActivity> getFriendActivityStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(FriendActivity.empty());

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      if (friendIds.isEmpty) return FriendActivity.empty();

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      final recentActivities = <ActivityItem>[];
      
      for (final friendId in friendIds) {
        final betsQuery = await _firestore
            .collection('bets')
            .where('userId', isEqualTo: friendId)
            .where('settledAt', isGreaterThan: yesterday)
            .orderBy('settledAt', descending: true)
            .limit(1)
            .get();

        if (betsQuery.docs.isNotEmpty) {
          final bet = betsQuery.docs.first.data();
          final userDoc = await _firestore
              .collection('users')
              .doc(friendId)
              .get();
          
          final username = userDoc.data()?['username'] ?? 'Unknown';
          final won = bet['won'] ?? false;
          final amount = (bet['amount'] ?? 0).toDouble();
          
          recentActivities.add(ActivityItem(
            username: username,
            action: won ? 'Won' : 'Lost',
            amount: amount,
            sport: bet['sport'] ?? 'Unknown',
            time: bet['settledAt'].toDate(),
          ));
        }
      }

      recentActivities.sort((a, b) => b.time.compareTo(a.time));
      
      return FriendActivity(
        recentActivities: recentActivities.take(3).toList(),
        totalFriends: friendIds.length,
      );
    });
  }

  Future<void> acceptFriendRequest(String requesterId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(userId), {
      'friends': FieldValue.arrayUnion([requesterId]),
      'friendRequests': FieldValue.arrayRemove([requesterId]),
    });

    batch.update(_firestore.collection('users').doc(requesterId), {
      'friends': FieldValue.arrayUnion([userId]),
    });

    final friendshipId = _getFriendshipId(userId, requesterId);
    batch.set(_firestore.collection('friendships').doc(friendshipId), {
      'users': [userId, requesterId],
      'createdAt': FieldValue.serverTimestamp(),
      'headToHead': {
        '${userId}Wins': 0,
        '${requesterId}Wins': 0,
        'totalBets': 0,
      },
      'sharedPools': [],
    });

    await batch.commit();
  }

  Future<void> removeFriend(String friendId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(userId), {
      'friends': FieldValue.arrayRemove([friendId]),
    });

    batch.update(_firestore.collection('users').doc(friendId), {
      'friends': FieldValue.arrayRemove([userId]),
    });

    final friendshipId = _getFriendshipId(userId, friendId);
    batch.delete(_firestore.collection('friendships').doc(friendshipId));

    await batch.commit();
  }

  String _getFriendshipId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<Map<String, dynamic>> getUserRankings() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    final userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .get();

    final userData = userDoc.data() ?? {};
    final state = userData['state'] ?? 'Unknown';
    final totalProfit = (userData['totalProfit'] ?? 0).toDouble();

    final stateQuery = await _firestore
        .collection('users')
        .where('state', isEqualTo: state)
        .orderBy('totalProfit', descending: true)
        .get();

    final nationalQuery = await _firestore
        .collection('users')
        .orderBy('totalProfit', descending: true)
        .limit(10000)
        .get();

    int stateRank = 0;
    int nationalRank = 0;

    for (int i = 0; i < stateQuery.docs.length; i++) {
      if (stateQuery.docs[i].id == userId) {
        stateRank = i + 1;
        break;
      }
    }

    for (int i = 0; i < nationalQuery.docs.length; i++) {
      if (nationalQuery.docs[i].id == userId) {
        nationalRank = i + 1;
        break;
      }
    }

    return {
      'stateRank': stateRank,
      'stateTotalUsers': stateQuery.docs.length,
      'nationalRank': nationalRank,
      'nationalTotalUsers': nationalQuery.docs.length,
      'state': state,
    };
  }
}

class FriendData {
  final String id;
  final String username;
  final String displayName;
  final double totalProfit;
  final double winRate;
  final int currentStreak;
  final DateTime lastActive;

  FriendData({
    required this.id,
    required this.username,
    required this.displayName,
    required this.totalProfit,
    required this.winRate,
    required this.currentStreak,
    required this.lastActive,
  });
}

class FriendActivity {
  final List<ActivityItem> recentActivities;
  final int totalFriends;

  FriendActivity({
    required this.recentActivities,
    required this.totalFriends,
  });

  factory FriendActivity.empty() {
    return FriendActivity(
      recentActivities: [],
      totalFriends: 0,
    );
  }
}

class ActivityItem {
  final String username;
  final String action;
  final double amount;
  final String sport;
  final DateTime time;

  ActivityItem({
    required this.username,
    required this.action,
    required this.amount,
    required this.sport,
    required this.time,
  });
}