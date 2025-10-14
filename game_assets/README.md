# Game Assets Organization

This folder contains visual assets for all mini-games in the Bragging Rights app.

## Folder Structure

```
game_assets/
├── marble_run/
│   ├── thumbnail.jpg      # Card preview (512x512 recommended)
│   ├── banner.jpg         # Featured section (1280x720 recommended)
│   ├── gameplay.jpg       # Gameplay screenshot
│   ├── image4.jpg         # Additional asset
│   ├── image5.jpg         # Additional asset
│   └── game_title.txt     # Official game title
├── sports_trivia/
│   └── (to be added)
└── README.md
```

## Image Guidelines

### Thumbnail (for game cards)
- **Size**: 512x512px or 800x600px
- **Format**: JPG or PNG
- **Usage**: Grid view, list view, small previews
- **File**: `thumbnail.jpg`

### Banner (for featured section)
- **Size**: 1280x720px (16:9 ratio)
- **Format**: JPG or PNG
- **Usage**: Featured game section, hero banners
- **File**: `banner.jpg`

### Gameplay Screenshot
- **Size**: 800x600px or larger
- **Format**: JPG or PNG
- **Usage**: Game detail pages, previews
- **File**: `gameplay.jpg`

## Adding New Games

When adding a new game:

1. Create a folder with the game's slug name (lowercase, underscores)
   ```bash
   mkdir game_assets/basketball_stars
   ```

2. Add the three core images:
   - `thumbnail.jpg` - For card previews
   - `banner.jpg` - For featured displays
   - `gameplay.jpg` - For detail views

3. Add a `game_title.txt` with the official game name

4. Update the Firestore game document with image paths

## Firebase Storage Structure

When uploaded to Firebase Storage, use this structure:
```
/game_images/
  /marble_run/
    thumbnail.jpg
    banner.jpg
    gameplay.jpg
  /sports_trivia/
    thumbnail.jpg
    banner.jpg
    gameplay.jpg
```

## Usage in Flutter App

Reference images from Firebase Storage URLs:
```dart
final gameData = {
  'id': 'marble_run',
  'name': 'Marble Run - Ultimate Race!',
  'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../marble_run/thumbnail.jpg',
  'bannerUrl': 'https://firebasestorage.googleapis.com/.../marble_run/banner.jpg',
  'gameplayUrl': 'https://firebasestorage.googleapis.com/.../marble_run/gameplay.jpg',
};
```

## Notes

- All images should be optimized for web (compressed JPG or PNG)
- Keep file sizes reasonable (<500KB for thumbnails, <1MB for banners)
- Use consistent aspect ratios for better UI consistency
- Test images on both mobile and desktop displays
