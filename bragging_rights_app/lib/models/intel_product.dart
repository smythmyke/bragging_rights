import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class IntelProduct {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final String detailedDescription;
  final int price;
  final String imagePath;
  final Color color;
  final List<String> features;
  
  const IntelProduct({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.detailedDescription,
    required this.price,
    required this.imagePath,
    required this.color,
    required this.features,
  });
}

class IntelProducts {
  static final List<IntelProduct> all = [
    const IntelProduct(
      id: 'live_game_intel',
      name: 'Live Game Intel',
      icon: PhosphorIconsRegular.lightning,
      description: 'Real-time insights',
      detailedDescription: 'Get real-time data feeds, momentum shifts, and critical game moments as they happen. Updated every 30 seconds during live games.',
      price: 250,
      imagePath: 'assets/images/cards/live_game_intel.png',
      color: Colors.yellow,
      features: [
        'Real-time momentum tracking',
        'Key play alerts',
        'Live injury updates',
        'Weather condition changes',
      ],
    ),
    const IntelProduct(
      id: 'pre_game_analysis',
      name: 'Pre-Game Analysis',
      icon: PhosphorIconsRegular.chartLine,
      description: 'Statistical breakdown',
      detailedDescription: 'Comprehensive pre-game statistics, head-to-head history, recent form analysis, and key player matchups.',
      price: 150,
      imagePath: 'assets/images/cards/pre_game_analysis.png',
      color: Colors.blue,
      features: [
        'Head-to-head history',
        'Recent form analysis',
        'Key player matchups',
        'Statistical trends',
      ],
    ),
    const IntelProduct(
      id: 'expert_picks',
      name: 'Expert Picks',
      icon: PhosphorIconsRegular.target,
      description: 'Pro predictions',
      detailedDescription: 'Access predictions from verified sports analysts with 70%+ accuracy. See consensus picks and contrarian plays.',
      price: 300,
      imagePath: 'assets/images/cards/expert_picks.png',
      color: Colors.purple,
      features: [
        'Verified expert predictions',
        '70%+ accuracy rate',
        'Consensus vs contrarian plays',
        'Confidence ratings',
      ],
    ),
    const IntelProduct(
      id: 'injury_reports',
      name: 'Injury Reports',
      icon: PhosphorIconsRegular.firstAid,
      description: 'Latest updates',
      detailedDescription: 'Real-time injury updates, player availability status, and impact analysis on game outcomes.',
      price: 100,
      imagePath: 'assets/images/cards/injury_reports.png',
      color: Colors.red,
      features: [
        'Real-time injury updates',
        'Player availability status',
        'Impact analysis',
        'Recovery timelines',
      ],
    ),
    const IntelProduct(
      id: 'weather_report',
      name: 'Weather Report',
      icon: PhosphorIconsRegular.cloudSun,
      description: 'Game time conditions',
      detailedDescription: 'Detailed weather forecast for game time including wind, temperature, humidity, and precipitation.',
      price: 50,
      imagePath: 'assets/images/cards/weather_report.png',
      color: Colors.cyan,
      features: [
        'Game time forecast',
        'Wind speed and direction',
        'Temperature and humidity',
        'Precipitation probability',
      ],
    ),
  ];
}