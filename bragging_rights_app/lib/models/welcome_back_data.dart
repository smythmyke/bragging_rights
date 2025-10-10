import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Welcome Back overlay data
class WelcomeBackData {
  final DateTime lastLoginAt;
  final int oldBalance;
  final int newBalance;
  final List<SettledBet> settledBets;
  final int oldGlobalRank;
  final int newGlobalRank;
  final int oldFriendsRank;
  final int newFriendsRank;
  final List<String> friendsPassed;
  final int activeBetsCount;
  final int totalBets;
  final int wins;
  final int losses;
  final double winRate;
  final int currentStreak;
  final int totalProfit;

  WelcomeBackData({
    required this.lastLoginAt,
    required this.oldBalance,
    required this.newBalance,
    required this.settledBets,
    required this.oldGlobalRank,
    required this.newGlobalRank,
    required this.oldFriendsRank,
    required this.newFriendsRank,
    required this.friendsPassed,
    required this.activeBetsCount,
    required this.totalBets,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.currentStreak,
    required this.totalProfit,
  });

  // Calculate net balance change
  int get balanceChange => newBalance - oldBalance;

  // Calculate percentage change
  double get balanceChangePercentage {
    if (oldBalance == 0) return 0;
    return ((balanceChange / oldBalance) * 100);
  }

  // Calculate global rank change
  int get globalRankChange => oldGlobalRank - newGlobalRank;

  // Calculate friends rank change
  int get friendsRankChange => oldFriendsRank - newFriendsRank;

  // Calculate settled bets summary
  BetsSummary get settledBetsSummary {
    int wins = 0;
    int losses = 0;
    int netProfit = 0;

    for (var bet in settledBets) {
      if (bet.isWin) {
        wins++;
        netProfit += bet.amount;
      } else {
        losses++;
        netProfit -= bet.amount;
      }
    }

    return BetsSummary(wins: wins, losses: losses, netProfit: netProfit);
  }

  // Check if user has activity since last login
  bool get hasActivity {
    return settledBets.isNotEmpty ||
        balanceChange != 0 ||
        globalRankChange != 0 ||
        friendsRankChange != 0;
  }

  // Get time since last login in human-readable format
  String get timeSinceLastLogin {
    final now = DateTime.now();
    final difference = now.difference(lastLoginAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    }
  }
}

/// Model for settled bet in Welcome Back overlay
class SettledBet {
  final String id;
  final String gameName;
  final String betType;
  final int amount;
  final bool isWin;
  final DateTime settledAt;

  SettledBet({
    required this.id,
    required this.gameName,
    required this.betType,
    required this.amount,
    required this.isWin,
    required this.settledAt,
  });

  factory SettledBet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettledBet(
      id: doc.id,
      gameName: data['gameName'] ?? 'Unknown Game',
      betType: data['betType'] ?? 'Unknown',
      amount: data['amount'] ?? 0,
      isWin: data['result'] == 'won',
      settledAt: (data['settledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Summary of settled bets
class BetsSummary {
  final int wins;
  final int losses;
  final int netProfit;

  BetsSummary({
    required this.wins,
    required this.losses,
    required this.netProfit,
  });

  String get record => '$wins-$losses';
  bool get isProfit => netProfit > 0;
}
