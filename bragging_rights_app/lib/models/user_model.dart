import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final List<String> favoriteSports;
  final List<String> favoriteTeams;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isPremium;
  final bool isActive;

  // Wallet information (from subcollection)
  final int? brBalance;
  final int? lifetimeEarned;
  final int? lifetimeWagered;
  final DateTime? lastAllowance;

  // Statistics (from subcollection)
  final int? totalBets;
  final int? wins;
  final int? losses;
  final double? winRate;
  final int? currentStreak;
  final int? bestStreak;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.favoriteSports,
    required this.favoriteTeams,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isPremium,
    required this.isActive,
    this.brBalance,
    this.lifetimeEarned,
    this.lifetimeWagered,
    this.lastAllowance,
    this.totalBets,
    this.wins,
    this.losses,
    this.winRate,
    this.currentStreak,
    this.bestStreak,
  });

  // Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? walletData,
    Map<String, dynamic>? statsData,
  ) {
    final data = doc.data()!;
    
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      photoURL: data['photoURL'],
      favoriteSports: List<String>.from(data['favoriteSports'] ?? []),
      favoriteTeams: List<String>.from(data['favoriteTeams'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPremium: data['isPremium'] ?? false,
      isActive: data['isActive'] ?? true,
      // Wallet data
      brBalance: walletData?['balance'],
      lifetimeEarned: walletData?['lifetimeEarned'],
      lifetimeWagered: walletData?['lifetimeWagered'],
      lastAllowance: walletData?['lastAllowance'] != null
          ? (walletData!['lastAllowance'] as Timestamp).toDate()
          : null,
      // Stats data
      totalBets: statsData?['totalBets'],
      wins: statsData?['wins'],
      losses: statsData?['losses'],
      winRate: statsData?['winRate']?.toDouble(),
      currentStreak: statsData?['currentStreak'],
      bestStreak: statsData?['bestStreak'],
    );
  }

  // Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'favoriteSports': favoriteSports,
      'favoriteTeams': favoriteTeams,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isPremium': isPremium,
      'isActive': isActive,
    };
  }

  // CopyWith method for updating user model
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    List<String>? favoriteSports,
    List<String>? favoriteTeams,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isPremium,
    bool? isActive,
    int? brBalance,
    int? lifetimeEarned,
    int? lifetimeWagered,
    DateTime? lastAllowance,
    int? totalBets,
    int? wins,
    int? losses,
    double? winRate,
    int? currentStreak,
    int? bestStreak,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      favoriteSports: favoriteSports ?? this.favoriteSports,
      favoriteTeams: favoriteTeams ?? this.favoriteTeams,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      brBalance: brBalance ?? this.brBalance,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeWagered: lifetimeWagered ?? this.lifetimeWagered,
      lastAllowance: lastAllowance ?? this.lastAllowance,
      totalBets: totalBets ?? this.totalBets,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      winRate: winRate ?? this.winRate,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  // Check if user needs weekly allowance
  bool needsWeeklyAllowance() {
    if (lastAllowance == null) return true;
    
    final now = DateTime.now();
    final daysSinceAllowance = now.difference(lastAllowance!).inDays;
    
    return daysSinceAllowance >= 7;
  }

  // Calculate user level based on lifetime earnings
  int getUserLevel() {
    if (lifetimeEarned == null) return 1;
    
    if (lifetimeEarned! < 1000) return 1;
    if (lifetimeEarned! < 5000) return 2;
    if (lifetimeEarned! < 10000) return 3;
    if (lifetimeEarned! < 25000) return 4;
    if (lifetimeEarned! < 50000) return 5;
    if (lifetimeEarned! < 100000) return 6;
    if (lifetimeEarned! < 250000) return 7;
    if (lifetimeEarned! < 500000) return 8;
    if (lifetimeEarned! < 1000000) return 9;
    return 10; // Max level
  }

  // Get user title based on level
  String getUserTitle() {
    switch (getUserLevel()) {
      case 1:
        return 'Rookie';
      case 2:
        return 'Amateur';
      case 3:
        return 'Semi-Pro';
      case 4:
        return 'Professional';
      case 5:
        return 'Expert';
      case 6:
        return 'Master';
      case 7:
        return 'Champion';
      case 8:
        return 'Legend';
      case 9:
        return 'Hall of Famer';
      case 10:
        return 'GOAT';
      default:
        return 'Player';
    }
  }

  // Get streak status
  String getStreakStatus() {
    if (currentStreak == null) return 'No streak';
    
    if (currentStreak! > 0) {
      return '🔥 ${currentStreak} win streak';
    } else if (currentStreak! < 0) {
      return '❄️ ${currentStreak!.abs()} loss streak';
    } else {
      return 'No active streak';
    }
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, displayName: $displayName, email: $email, '
        'brBalance: $brBalance, level: ${getUserLevel()}, title: ${getUserTitle()})';
  }
}