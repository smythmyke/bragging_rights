import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BetStorageService {
  static const String _activeBetsKey = 'active_bets';
  static const String _pastBetsKey = 'past_bets';
  static const String _poolBetsKey = 'pool_bets';
  
  final SharedPreferences _prefs;
  
  BetStorageService._(this._prefs);
  
  static Future<BetStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BetStorageService._(prefs);
  }
  
  // Save a bet for a specific pool and game
  Future<void> saveBet(UserBet bet) async {
    final activeBets = await getActiveBets();
    
    // Remove any existing bet for the same game/pool to avoid duplicates
    activeBets.removeWhere((b) => 
      b.poolId == bet.poolId && 
      b.gameId == bet.gameId &&
      b.betType == bet.betType
    );
    
    activeBets.add(bet);
    
    final jsonList = activeBets.map((b) => b.toJson()).toList();
    await _prefs.setString(_activeBetsKey, jsonEncode(jsonList));
    
    // Also save pool-specific bets for quick lookup
    await _savePoolBets(bet);
  }
  
  // Save multiple bets at once (for when user locks in all bets)
  Future<void> saveBets(List<UserBet> bets) async {
    print('[BetStorageService] Saving ${bets.length} bets...');
    for (final bet in bets) {
      print('[BetStorageService] Bet: ${bet.selection} - Pool: ${bet.poolId}, Game: ${bet.gameId}');
    }
    
    final activeBets = await getActiveBets();
    print('[BetStorageService] Current active bets: ${activeBets.length}');
    
    // Remove any existing bets for the same pool/game
    for (final bet in bets) {
      activeBets.removeWhere((b) => 
        b.poolId == bet.poolId && 
        b.gameId == bet.gameId &&
        b.betType == bet.betType
      );
    }
    
    activeBets.addAll(bets);
    print('[BetStorageService] Total active bets after save: ${activeBets.length}');
    
    final jsonList = activeBets.map((b) => b.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_activeBetsKey, jsonString);
    print('[BetStorageService] Saved to SharedPreferences key: $_activeBetsKey');
    
    // Save pool-specific bets
    for (final bet in bets) {
      await _savePoolBets(bet);
    }
  }
  
  // Get all active bets
  Future<List<UserBet>> getActiveBets() async {
    final jsonString = _prefs.getString(_activeBetsKey);
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => UserBet.fromJson(json)).toList();
  }
  
  // Get bets for a specific pool
  Future<List<UserBet>> getPoolBets(String poolId) async {
    final allBets = await getActiveBets();
    return allBets.where((bet) => bet.poolId == poolId).toList();
  }
  
  // Get bets for a specific game within a pool
  Future<List<UserBet>> getGameBets(String poolId, String gameId) async {
    final allBets = await getActiveBets();
    return allBets.where((bet) => 
      bet.poolId == poolId && bet.gameId == gameId
    ).toList();
  }
  
  // Check if user has bets in a pool
  Future<bool> hasPoolBets(String poolId) async {
    final poolBets = await getPoolBets(poolId);
    return poolBets.isNotEmpty;
  }
  
  // Get count of bets in a pool
  Future<int> getPoolBetCount(String poolId) async {
    final poolBets = await getPoolBets(poolId);
    return poolBets.length;
  }
  
  // Move completed bets to past bets
  Future<void> moveToPastBets(String gameId) async {
    final activeBets = await getActiveBets();
    final pastBets = await getPastBets();
    
    final completedBets = activeBets.where((bet) => bet.gameId == gameId).toList();
    final remainingBets = activeBets.where((bet) => bet.gameId != gameId).toList();
    
    // Update timestamps and add to past bets
    for (final bet in completedBets) {
      bet.completedAt = DateTime.now();
      pastBets.add(bet);
    }
    
    // Save updated lists
    await _prefs.setString(_activeBetsKey, jsonEncode(remainingBets.map((b) => b.toJson()).toList()));
    await _prefs.setString(_pastBetsKey, jsonEncode(pastBets.map((b) => b.toJson()).toList()));
  }
  
  // Get past bets
  Future<List<UserBet>> getPastBets() async {
    final jsonString = _prefs.getString(_pastBetsKey);
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => UserBet.fromJson(json)).toList();
  }
  
  // Clear all bets (for testing or user logout)
  Future<void> clearAllBets() async {
    await _prefs.remove(_activeBetsKey);
    await _prefs.remove(_pastBetsKey);
    await _prefs.remove(_poolBetsKey);
  }
  
  // Private helper to save pool-specific bet info
  Future<void> _savePoolBets(UserBet bet) async {
    final key = '${_poolBetsKey}_${bet.poolId}';
    final poolBetsJson = _prefs.getString(key);
    
    Map<String, dynamic> poolData = {};
    if (poolBetsJson != null) {
      poolData = jsonDecode(poolBetsJson);
    }
    
    // Track bet counts and last activity
    poolData['betCount'] = (poolData['betCount'] ?? 0) + 1;
    poolData['lastActivity'] = DateTime.now().toIso8601String();
    poolData['poolName'] = bet.poolName;
    
    await _prefs.setString(key, jsonEncode(poolData));
  }
  
  // Get pool summary (for showing on pool selection screen)
  Future<Map<String, dynamic>?> getPoolSummary(String poolId) async {
    final key = '${_poolBetsKey}_$poolId';
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    
    return jsonDecode(jsonString);
  }
}

// User Bet Model
class UserBet {
  final String id;
  final String poolId;
  final String poolName;
  final String gameId;
  final String gameTitle;
  final String sport;
  final String betType; // moneyline, spread, total, prop, etc.
  final String selection; // The actual bet selection
  final String odds;
  final double amount; // BR amount
  final DateTime placedAt;
  DateTime? completedAt;
  bool? won; // null = pending, true = won, false = lost
  double? payout; // BR payout amount if won
  
  // Additional info for display
  final String? description;
  final Map<String, dynamic>? metadata; // Store additional data like spread value, total line, etc.
  
  UserBet({
    required this.id,
    required this.poolId,
    required this.poolName,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.betType,
    required this.selection,
    required this.odds,
    required this.amount,
    required this.placedAt,
    this.completedAt,
    this.won,
    this.payout,
    this.description,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poolId': poolId,
      'poolName': poolName,
      'gameId': gameId,
      'gameTitle': gameTitle,
      'sport': sport,
      'betType': betType,
      'selection': selection,
      'odds': odds,
      'amount': amount,
      'placedAt': placedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'won': won,
      'payout': payout,
      'description': description,
      'metadata': metadata,
    };
  }
  
  factory UserBet.fromJson(Map<String, dynamic> json) {
    return UserBet(
      id: json['id'],
      poolId: json['poolId'],
      poolName: json['poolName'],
      gameId: json['gameId'],
      gameTitle: json['gameTitle'],
      sport: json['sport'],
      betType: json['betType'],
      selection: json['selection'],
      odds: json['odds'],
      amount: (json['amount'] as num).toDouble(),
      placedAt: DateTime.parse(json['placedAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      won: json['won'],
      payout: json['payout']?.toDouble(),
      description: json['description'],
      metadata: json['metadata'],
    );
  }
  
  // Helper to check if bet is still active
  bool get isActive => completedAt == null;
  
  // Helper to get status text
  String get statusText {
    if (won == null) return 'Pending';
    return won! ? 'Won' : 'Lost';
  }
  
  // Helper to get formatted payout
  String get formattedPayout {
    if (payout == null) return '-';
    return '+${payout!.toStringAsFixed(0)} BR';
  }
}