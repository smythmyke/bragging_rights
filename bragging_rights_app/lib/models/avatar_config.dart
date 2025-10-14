import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration model for DiceBear avatars
/// Stores all customization options for generating consistent avatars
class AvatarConfig {
  final String style;
  final String seed;
  final String? backgroundColor;
  final String? backgroundType;
  final int? backgroundRotation;
  final int? radius;
  final int? scale;
  final Map<String, dynamic>? styleOptions;  // Style-specific options
  final DateTime createdAt;
  final bool isFavorite;
  final String? rarity;  // 'common', 'rare', 'epic', 'legendary'

  AvatarConfig({
    required this.style,
    required this.seed,
    this.backgroundColor,
    this.backgroundType = 'solid',
    this.backgroundRotation,
    this.radius = 0,
    this.scale = 100,
    this.styleOptions,
    DateTime? createdAt,
    this.isFavorite = false,
    this.rarity = 'common',
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generate DiceBear URL from config
  String toUrl() {
    final buffer = StringBuffer('https://api.dicebear.com/7.x/$style/svg?seed=$seed');

    if (backgroundColor != null && backgroundColor!.isNotEmpty) {
      buffer.write('&backgroundColor=$backgroundColor');
    }
    if (backgroundType != null && backgroundType != 'solid') {
      buffer.write('&backgroundType=$backgroundType');
    }
    if (backgroundRotation != null && backgroundRotation != 0) {
      buffer.write('&backgroundRotation=$backgroundRotation');
    }
    if (radius != null && radius != 0) {
      buffer.write('&radius=$radius');
    }
    if (scale != null && scale != 100) {
      buffer.write('&scale=$scale');
    }

    // Add style-specific options
    styleOptions?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        buffer.write('&$key=$value');
      }
    });

    return buffer.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'style': style,
      'seed': seed,
      'backgroundColor': backgroundColor,
      'backgroundType': backgroundType,
      'backgroundRotation': backgroundRotation,
      'radius': radius,
      'scale': scale,
      'styleOptions': styleOptions,
      'createdAt': Timestamp.fromDate(createdAt),
      'isFavorite': isFavorite,
      'rarity': rarity,
    };
  }

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      style: map['style'] ?? 'adventurer',
      seed: map['seed'] ?? '',
      backgroundColor: map['backgroundColor'],
      backgroundType: map['backgroundType'] ?? 'solid',
      backgroundRotation: map['backgroundRotation'],
      radius: map['radius'] ?? 0,
      scale: map['scale'] ?? 100,
      styleOptions: map['styleOptions'] != null
          ? Map<String, dynamic>.from(map['styleOptions'])
          : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isFavorite: map['isFavorite'] ?? false,
      rarity: map['rarity'] ?? 'common',
    );
  }

  AvatarConfig copyWith({
    String? style,
    String? seed,
    String? backgroundColor,
    String? backgroundType,
    int? backgroundRotation,
    int? radius,
    int? scale,
    Map<String, dynamic>? styleOptions,
    bool? isFavorite,
    String? rarity,
  }) {
    return AvatarConfig(
      style: style ?? this.style,
      seed: seed ?? this.seed,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundRotation: backgroundRotation ?? this.backgroundRotation,
      radius: radius ?? this.radius,
      scale: scale ?? this.scale,
      styleOptions: styleOptions ?? this.styleOptions,
      createdAt: this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      rarity: rarity ?? this.rarity,
    );
  }

  @override
  String toString() {
    return 'AvatarConfig(style: $style, seed: $seed, backgroundColor: $backgroundColor)';
  }
}
