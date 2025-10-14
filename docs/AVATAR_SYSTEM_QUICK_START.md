# Avatar System Quick Start Guide

## Overview
The Bragging Rights app now includes a complete avatar customization system powered by DiceBear. Users can select from multiple avatar styles, customize backgrounds, and unlock new styles through achievements.

## Testing the Avatar System

### Step 1: Launch the App
```bash
cd bragging_rights_app
flutter run
```

### Step 2: Navigate to Profile Edit
1. Open the app
2. Tap the **"Edge"** tab at the bottom navigation (4th tab)
3. Look for your avatar at the top of the screen
4. Tap the **pencil/edit icon** next to the avatar

### Step 3: Edit Your Profile
You should now see the **Profile Edit Screen** with:
- Large avatar preview
- Display name field
- Email (read-only)
- "Change Avatar" button or edit icon on the avatar

### Step 4: Select an Avatar
1. Tap the **"Change Avatar"** button
2. You'll see the **Avatar Selection Screen** with:
   - Large live preview at the top
   - Grid of 8 avatar styles below
   - Background color selector
   - Randomize button
   - Save button

### Step 5: Customize Your Avatar
1. **Select a Style**: Tap on any unlocked avatar style card
   - Common styles are unlocked by default
   - Locked styles show a lock icon
2. **Choose a Background Color**: Tap color circles or use the color picker
3. **Randomize**: Tap the shuffle icon to generate a random seed
4. **Preview**: Watch the live preview update in real-time

### Step 6: Save Your Avatar
1. Tap the **"Save Avatar"** button
2. You'll be returned to the Profile Edit Screen
3. Your new avatar should be visible

### Step 7: Verify Avatar Throughout App
Your avatar should now appear in:
- Home screen "Edge" tab (top of More section)
- Profile Edit Screen
- Any other locations where user profiles are displayed

## Available Avatar Styles

### Common (Unlocked by Default)
- **Adventurer**: Fun cartoon style
- **Bottts**: Robot avatars

### Rare (Unlock Condition: TBD)
- **Lorelei**: Modern illustrated style
- **Micah**: Geometric avatars

### Epic (Unlock Condition: TBD)
- **Personas**: Professional business style
- **Thumbs**: Classic comic style

### Legendary (Unlock Condition: TBD)
- **Big Smile**: Happy, expressive faces
- **Notionists**: Sketch-style avatars

## Background Colors
10 preset colors available:
- Transparent
- Blue (b6e3f4)
- Red (d1d4f9)
- Green (c0aede)
- Yellow (ffd5dc)
- Purple (ffdfbf)
- Orange (4CAF50)
- Pink (FF9800)
- Cyan (E91E63)
- Lime (00BCD4)

## Technical Architecture

### Files Created
```
lib/models/avatar_config.dart           - Avatar data model
lib/services/avatar_service.dart        - Avatar business logic
lib/widgets/user_avatar.dart            - Reusable avatar widget
lib/screens/profile/profile_edit_screen.dart    - Profile editing
lib/screens/profile/avatar_selection_screen.dart - Avatar selection
```

### Files Modified
```
lib/models/user_model.dart              - Added avatar fields
lib/screens/home/home_screen.dart       - Integrated avatar display
pubspec.yaml                            - Added flutter_colorpicker
firestore.rules                         - Added favorite avatars rules
```

### Data Flow
1. User selects avatar style + customization
2. `AvatarConfig` generates DiceBear URL
3. Config saved to Firestore at `/users/{userId}`
4. URL generated on-the-fly from config
5. SVG rendered via `flutter_svg` package

## Integration Examples

### Display User Avatar Anywhere
```dart
import '../widgets/user_avatar.dart';

// Basic usage
UserAvatar(
  userId: currentUser.uid,
  photoURL: currentUser.photoURL,
  radius: 40,
)

// With explicit config
UserAvatar(
  avatarConfig: userAvatarConfig,
  radius: 60,
)

// Large with edit button
LargeUserAvatar(
  photoURL: user.photoURL,
  avatarConfig: user.avatarConfig,
  userId: user.uid,
  radius: 80,
  onEditTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarSelectionScreen(),
      ),
    );
  },
)
```

### Check Unlocked Styles
```dart
final avatarService = AvatarService();
final unlockedStyles = await avatarService.checkAndUnlockStyles();
print('User has ${unlockedStyles.length} styles unlocked');
```

### Generate Avatar URL
```dart
final url = AvatarService.generateSimpleAvatarUrl(
  seed: 'user123',
  style: 'adventurer',
  backgroundColor: 'b6e3f4',
);
```

## Troubleshooting

### Avatar Not Displaying
1. Check internet connection (DiceBear requires network)
2. Verify Firestore rules are deployed
3. Check console for SVG loading errors
4. Ensure `flutter_svg` package is installed

### Navigation Error to Profile Edit
If you see "Could not find a generator for route":
- Ensure using `Navigator.push()` with MaterialPageRoute
- Not using `Navigator.pushNamed()` (unless route registered in main.dart)
- Import statement present: `import '../profile/profile_edit_screen.dart';`

### Styles Not Unlocking
1. Check unlock conditions in `avatar_service.dart`
2. Verify user stats in Firestore
3. Call `checkAndUnlockStyles()` after achievements
4. Check `unlockedStyles` array in user document

### Save Not Working
1. Check Firestore permissions
2. Verify user is authenticated
3. Check console for errors
4. Ensure `avatarConfig` is valid JSON

## Future Enhancements

Potential features to add:
- [ ] More customization options (accessories, facial features)
- [ ] Favorites management UI
- [ ] Avatar history/presets
- [ ] Social features (view other users' avatars)
- [ ] Achievement tracking dashboard
- [ ] Style unlock animations
- [ ] Custom upload option
- [ ] Avatar marketplace (purchase premium styles with BR)

## Support

For issues or questions:
1. Check Firestore console for data persistence
2. Review Flutter console for errors
3. Verify DiceBear API status at https://www.dicebear.com/
4. Check documentation at `docs/AVATAR_SYSTEM_BUILD.md`

## API Reference

### DiceBear Base URL
```
https://api.dicebear.com/7.x/{style}/svg
```

### Common Parameters
- `seed`: Unique identifier for avatar generation
- `backgroundColor`: Hex color (without #)
- `radius`: Border radius (0-50)
- `scale`: Size scaling (0-100)

Full parameter list available in `AVATAR_SYSTEM_BUILD.md`.
