import 'package:cloud_firestore/cloud_firestore.dart';

class OddsModel {
  final double? homeMoneyline;
  final double? awayMoneyline;
  final double? spread;
  final double? spreadHomeOdds;
  final double? spreadAwayOdds;
  final double? totalPoints;
  final double? overOdds;
  final double? underOdds;
  final DateTime? lastUpdated;
  final String? bookmaker;

  OddsModel({
    this.homeMoneyline,
    this.awayMoneyline,
    this.spread,
    this.spreadHomeOdds,
    this.spreadAwayOdds,
    this.totalPoints,
    this.overOdds,
    this.underOdds,
    this.lastUpdated,
    this.bookmaker,
  });

  factory OddsModel.fromMap(Map<String, dynamic> map) {
    return OddsModel(
      homeMoneyline: _parseDouble(map['homeMoneyline']),
      awayMoneyline: _parseDouble(map['awayMoneyline']),
      spread: _parseDouble(map['spread']),
      spreadHomeOdds: _parseDouble(map['spreadHomeOdds']),
      spreadAwayOdds: _parseDouble(map['spreadAwayOdds']),
      totalPoints: _parseDouble(map['totalPoints']),
      overOdds: _parseDouble(map['overOdds']),
      underOdds: _parseDouble(map['underOdds']),
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
      bookmaker: map['bookmaker'],
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Format odds for display (American format)
  String formatMoneyline(double? odds) {
    if (odds == null) return '--';
    if (odds > 0) return '+${odds.toStringAsFixed(0)}';
    return odds.toStringAsFixed(0);
  }

  String formatSpread(double? spread, {bool isHome = true}) {
    if (spread == null) return '--';
    final value = isHome ? spread : -spread;
    if (value > 0) return '+${value.toStringAsFixed(1)}';
    return value.toStringAsFixed(1);
  }

  String formatTotal(double? total) {
    if (total == null) return '--';
    return total.toStringAsFixed(1);
  }

  Map<String, dynamic> toMap() {
    return {
      'homeMoneyline': homeMoneyline,
      'awayMoneyline': awayMoneyline,
      'spread': spread,
      'spreadHomeOdds': spreadHomeOdds,
      'spreadAwayOdds': spreadAwayOdds,
      'totalPoints': totalPoints,
      'overOdds': overOdds,
      'underOdds': underOdds,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'bookmaker': bookmaker,
    };
  }
}