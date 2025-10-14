# 🎨 Avatar System Build Guide - DiceBear Integration

## Overview
This document outlines the implementation of a full-featured avatar customization system using DiceBear Avatars API for Bragging Rights app.

---

## Table of Contents
1. [Features](#features)
2. [Architecture](#architecture)
3. [DiceBear API Reference](#dicebear-api-reference)
4. [Data Models](#data-models)
5. [Services](#services)
6. [Screens](#screens)
7. [Implementation Steps](#implementation-steps)
8. [Testing Checklist](#testing-checklist)

---

## Features

### Phase 1: Core Avatar System ✅
- [x] Profile Edit Screen
- [x] Avatar Selection Screen with multiple styles
- [x] Real-time preview
- [x] Save avatar to Firestore
- [x] Display avatar throughout app

### Phase 2: Customization ✅
- [x] 7+ avatar styles (Adventurer, Avataaars, Bottts, etc.)
- [x] Background color picker
- [x] Randomize button for instant new avatar
- [x] Custom seed input
- [x] Style-specific options (accessories, hair, etc.)
- [x] Preview variations grid

### Phase 3: Advanced Features ✅
- [x] Avatar favorites/save multiple
- [x] Achievement-based unlocks
- [x] Rarity tiers (Common, Rare, Epic, Legendary)
- [x] Share avatar as image
- [ ] Animated avatar support (future)

---

## Architecture

```
lib/
├── models/
│   ├── user_model.dart (UPDATED)
│   └── avatar_config.dart (NEW)
├── services/
│   ├── avatar_service.dart (NEW)
│   └── user_service.dart (UPDATED)
├── screens/
│   └── profile/
│       ├── profile_edit_screen.dart (NEW)
│       ├── avatar_selection_screen.dart (NEW)
│       └── widgets/
│           ├── avatar_preview.dart (NEW)
│           ├── avatar_style_card.dart (NEW)
│           ├── color_picker_widget.dart (NEW)
│           └── avatar_customization_panel.dart (NEW)
└── widgets/
    └── user_avatar.dart (NEW - reusable avatar widget)
```

---

## DiceBear API Reference

### Base URL
```
https://api.dicebear.com/7.x/{style}/svg
```

### Available Styles
| Style | Description | Best For |
|-------|-------------|----------|
| `adventurer` | Cartoon people with accessories | General use, most customizable |
| `adventurer-neutral` | Adventurer without gender-specific options | Neutral avatars |
| `avataaars` | Popular cartoon style (Sketch-inspired) | Classic look |
| `avataaars-neutral` | Avataaars without gender options | Neutral avatars |
| `big-ears` | Characters with prominent ears | Playful, cartoony |
| `big-ears-neutral` | Big ears without gender | Neutral playful |
| `big-smile` | Always smiling faces | Positive vibes |
| `bottts` | Cute robots | Sci-fi fans |
| `bottts-neutral` | Robots without gender cues | Neutral robots |
| `croodles` | Doodle-style characters | Artistic |
| `croodles-neutral` | Doodles without gender | Neutral artistic |
| `fun-emoji` | Emoji-style faces | Simple, recognizable |
| `icons` | Abstract geometric icons | Minimalist |
| `identicon` | GitHub-style geometric patterns | Tech aesthetic |
| `initials` | Text-based with initials | Professional |
| `lorelei` | Illustration-style portraits | Elegant |
| `lorelei-neutral` | Lorelei without gender | Neutral elegant |
| `micah` | Hand-drawn style | Unique, artsy |
| `miniavs` | Minimalist avatars | Clean, simple |
| `open-peeps` | Mix-and-match illustrations | Very customizable |
| `personas` | Abstract faces | Modern, artistic |
| `pixel-art` | 8-bit retro style | Retro gamers |
| `pixel-art-neutral` | Pixel art without gender | Neutral retro |
| `thumbs` | Thumbs up avatars | Always positive |

### Common Parameters

#### Universal Options (All Styles)
```
?seed=string              // Unique identifier for consistent generation
&backgroundColor=hex      // Background color (e.g., b6e3f4, random, transparent)
&backgroundType=solid     // solid or gradientLinear
&backgroundRotation=0     // 0-360 degrees for gradients
&radius=0                 // Border radius 0-50
&scale=100                // Size scale 0-200 (percentage)
&rotate=0                 // Rotation -360 to 360 degrees
&translateX=0             // Horizontal offset -100 to 100
&translateY=0             // Vertical offset -100 to 100
&flip=false               // Flip horizontally
&size=128                 // Output size in pixels
&format=svg               // svg, png, jpg, webp
```

#### Style-Specific Options (Examples)

**Adventurer:**
```
&skinColor=variant01,variant02,variant03...
&hair=long01,long02,short01...
&hairColor=0e0e0e,3eac2c,6a4e35...
&eyes=variant01,variant02...
&mouth=variant01,variant02...
&accessories=birthmark,freckles,glasses...
&accessoriesColor=random
```

**Avataaars:**
```
&accessories=kurt,prescription01,prescription02...
&accessoriesColor=random
&accessoriesProbability=100
&clothesColor=random
&clothing=blazerShirt,blazerSweater...
&eyebrows=default,defaultNatural,angry...
&eyes=default,happy,surprised...
&facialHair=medium,light,majestic...
&facialHairColor=random
&hairColor=random
&mouth=default,smile,twinkle...
&skinColor=tanned,yellow,pale...
&top=longHairBigHair,longHairBob...
```

**Bottts:**
```
&colors=amber,blue,blueGrey,brown,cyan...
&eyes=bulging,dizzy,eva,frame1...
&face=square01,square02,round01...
&mouth=bite,diagram,grill01...
&sides=antenna01,cables01,round...
&texture=camo01,camo02,circuits...
&top=antenna01,bulb01,glowingStar...
```

### Example URLs

**Basic Avatar:**
```
https://api.dicebear.com/7.x/adventurer/svg?seed=Felix
```

**Customized Avatar:**
```
https://api.dicebear.com/7.x/adventurer/svg?seed=Felix&backgroundColor=b6e3f4&hair=short01&eyes=variant02&mouth=variant03
```

**Random Avatar:**
```
https://api.dicebear.com/7.x/bottts/svg?seed=${timestamp}&backgroundColor=random
```

**Advanced Customization:**
```
https://api.dicebear.com/7.x/avataaars/svg?seed=user123&backgroundColor=65c9ff&backgroundType=gradientLinear&backgroundRotation=45&accessories=prescription02&accessoriesColor=262e33&clothing=blazerSweater&clothesColor=3c4f5c&eyebrows=default&eyes=happy&mouth=smile&skinColor=ffdbb4&top=shortHairShortFlat&hairColor=724133
```

---

## Data Models

### UserModel Updates
```dart
// Add to lib/models/user_model.dart

class UserModel {
  // Existing fields...
  final String? photoURL;

  // NEW Avatar fields
  final String? avatarStyle;        // e.g., 'adventurer'
  final String? avatarSeed;         // Custom seed for consistency
  final Map<String, dynamic>? avatarConfig;  // Customization options
  final List<String>? favoriteAvatars;  // Saved avatar configurations
  final List<String>? unlockedStyles;   // Achievement-unlocked styles

  // Constructor, fromFirestore, toFirestore updated accordingly
}
```

### AvatarConfig Model (NEW)
```dart
// lib/models/avatar_config.dart

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

  // Generate DiceBear URL from config
  String toUrl() {
    final buffer = StringBuffer('https://api.dicebear.com/7.x/$style/svg?seed=$seed');

    if (backgroundColor != null) {
      buffer.write('&backgroundColor=$backgroundColor');
    }
    if (backgroundType != null) {
      buffer.write('&backgroundType=$backgroundType');
    }
    if (backgroundRotation != null) {
      buffer.write('&backgroundRotation=$backgroundRotation');
    }
    if (radius != null) {
      buffer.write('&radius=$radius');
    }
    if (scale != null) {
      buffer.write('&scale=$scale');
    }

    // Add style-specific options
    styleOptions?.forEach((key, value) {
      buffer.write('&$key=$value');
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
}
```

---

## Services

### AvatarService (NEW)
```dart
// lib/services/avatar_service.dart

class AvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Available styles with metadata
  static const List<Map<String, dynamic>> availableStyles = [
    {
      'id': 'adventurer',
      'name': 'Adventurer',
      'description': 'Cartoon people with accessories',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'avataaars',
      'name': 'Avataaars',
      'description': 'Popular cartoon style',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'bottts',
      'name': 'Robots',
      'description': 'Cute robot avatars',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'big-smile',
      'name': 'Big Smile',
      'description': 'Always happy faces',
      'rarity': 'rare',
      'unlocked': false,
      'unlockCondition': 'Win 10 bets',
    },
    {
      'id': 'fun-emoji',
      'name': 'Fun Emoji',
      'description': 'Emoji-style faces',
      'rarity': 'rare',
      'unlocked': false,
      'unlockCondition': 'Reach Level 5',
    },
    {
      'id': 'lorelei',
      'name': 'Lorelei',
      'description': 'Elegant illustrations',
      'rarity': 'epic',
      'unlocked': false,
      'unlockCondition': 'Win 50 bets',
    },
    {
      'id': 'pixel-art',
      'name': 'Pixel Art',
      'description': 'Retro 8-bit style',
      'rarity': 'epic',
      'unlocked': false,
      'unlockCondition': 'Reach Level 10',
    },
    {
      'id': 'croodles',
      'name': 'Croodles',
      'description': 'Artistic doodles',
      'rarity': 'legendary',
      'unlocked': false,
      'unlockCondition': 'Win 100 bets',
    },
  ];

  // Background color presets
  static const List<String> backgroundColors = [
    'transparent',
    'b6e3f4', // Light blue
    'c0aede', // Light purple
    'ffd5dc', // Light pink
    'ffdfbf', // Light orange
    'd1f4dd', // Light green
    'fecaca', // Light red
    'fed7aa', // Peach
    'bfdbfe', // Sky blue
    'e9d5ff', // Lavender
  ];

  // Generate avatar URL from config
  static String generateAvatarUrl(AvatarConfig config) {
    return config.toUrl();
  }

  // Generate simple avatar URL
  static String generateSimpleAvatarUrl({
    required String seed,
    String style = 'adventurer',
    String? backgroundColor,
  }) {
    final buffer = StringBuffer('https://api.dicebear.com/7.x/$style/svg?seed=$seed');
    if (backgroundColor != null) {
      buffer.write('&backgroundColor=$backgroundColor');
    }
    return buffer.toString();
  }

  // Get user's current avatar config
  Future<AvatarConfig?> getUserAvatarConfig() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['avatarConfig'] != null) {
        return AvatarConfig.fromMap(Map<String, dynamic>.from(data['avatarConfig']));
      }

      // Return default config if none exists
      return AvatarConfig(
        style: 'adventurer',
        seed: user.uid,
      );
    } catch (e) {
      print('Error getting avatar config: $e');
      return null;
    }
  }

  // Save avatar config
  Future<bool> saveAvatarConfig(AvatarConfig config) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'avatarConfig': config.toMap(),
        'photoURL': config.toUrl(),
        'avatarStyle': config.style,
        'avatarSeed': config.seed,
      });

      print('✅ Avatar config saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving avatar config: $e');
      return false;
    }
  }

  // Save to favorites
  Future<bool> addToFavorites(AvatarConfig config) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final favoritesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_avatars')
          .doc();

      await favoritesRef.set(config.copyWith(isFavorite: true).toMap());
      return true;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  // Get favorite avatars
  Stream<List<AvatarConfig>> getFavoriteAvatars() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_avatars')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AvatarConfig.fromMap(doc.data()))
          .toList();
    });
  }

  // Check if style is unlocked
  Future<bool> isStyleUnlocked(String styleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final unlockedStyles = List<String>.from(doc.data()?['unlockedStyles'] ?? []);
      return unlockedStyles.contains(styleId);
    } catch (e) {
      print('Error checking unlock status: $e');
      return false;
    }
  }

  // Unlock style
  Future<bool> unlockStyle(String styleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unlockedStyles': FieldValue.arrayUnion([styleId]),
      });
      return true;
    } catch (e) {
      print('Error unlocking style: $e');
      return false;
    }
  }

  // Generate random seed
  static String generateRandomSeed() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
```

---

## Screens

### 1. Profile Edit Screen
**File:** `lib/screens/profile/profile_edit_screen.dart`

**Features:**
- Display current avatar
- Edit display name
- Navigate to avatar selection
- Show user stats
- Save profile changes

### 2. Avatar Selection Screen
**File:** `lib/screens/profile/avatar_selection_screen.dart`

**Features:**
- Large preview of current avatar
- Style tabs/carousel
- Randomize button
- Customization panel (background, colors, etc.)
- Grid of variations
- Save/Cancel buttons
- Lock indicators for locked styles

### 3. Supporting Widgets

**Avatar Preview Widget:**
- Real-time preview with zoom
- Loading states
- Error handling
- SVG rendering support

**Avatar Style Card:**
- Style thumbnail
- Name and description
- Lock/unlock status
- Rarity indicator

**Color Picker Widget:**
- Preset color palette
- Custom color input
- Visual preview

**Customization Panel:**
- Collapsible sections
- Style-specific options
- Sliders and toggles

---

## Implementation Steps

### Step 1: Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_svg: ^2.0.9  # For SVG rendering
  flutter_colorpicker: ^1.0.3  # Color picker
  cached_network_image: ^3.3.0  # Image caching
```

### Step 2: Create Models
1. Create `avatar_config.dart` model
2. Update `user_model.dart` with avatar fields

### Step 3: Create Service
1. Create `avatar_service.dart`
2. Implement all methods

### Step 4: Create Screens
1. Profile Edit Screen
2. Avatar Selection Screen
3. Supporting widgets

### Step 5: Update Existing Code
1. Replace CircleAvatar placeholders
2. Add navigation to profile edit
3. Update home screen user display

### Step 6: Firestore Rules
Add to `firestore.rules`:
```javascript
match /users/{userId}/favorite_avatars/{avatarId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId;
}
```

### Step 7: Testing
- Test all avatar styles
- Test customization options
- Test save/load functionality
- Test favorites system
- Test unlock system

---

## Testing Checklist

### Functional Tests
- [ ] Avatar displays correctly throughout app
- [ ] Avatar selection saves to Firestore
- [ ] Randomize generates new avatars
- [ ] Color picker changes background
- [ ] Style switching works
- [ ] Favorites save/load correctly
- [ ] Locked styles show properly
- [ ] Unlock achievements work

### UI/UX Tests
- [ ] Preview loads quickly
- [ ] Smooth transitions
- [ ] Responsive grid layout
- [ ] Touch targets are adequate
- [ ] Loading states show
- [ ] Error handling works

### Performance Tests
- [ ] SVG rendering is fast
- [ ] No memory leaks
- [ ] Network caching works
- [ ] Smooth scrolling in grid

### Edge Cases
- [ ] No internet connection
- [ ] Invalid seed values
- [ ] Missing style options
- [ ] First-time user (no config)
- [ ] Migration from old photoURL

---

## Future Enhancements
- Animated avatar styles
- Custom upload option
- Avatar marketplace (buy with BR)
- Seasonal/event avatars
- Avatar battles (compare with friends)
- AR try-on feature
- Export as profile pic for other platforms

---

## Resources
- DiceBear Docs: https://www.dicebear.com/
- All Options Guide: https://www.dicebear.com/guides/access-all-available-options/
- Style Playground: https://www.dicebear.com/playground
- API Reference: https://www.dicebear.com/docs
