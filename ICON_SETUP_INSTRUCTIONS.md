# App Icon Setup Instructions

## Step 1: Convert SVG to PNG

1. **Open this file in your browser:**
   `C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\convert_svg_to_png.html`

2. **Click "Download PNG (1024x1024)"** button

3. **Save the file as:** `br_initials_icon.png`

4. **Move it to:** `bragging_rights_app\assets\images\br_initials_icon.png`

## Step 2: Generate App Icons

Once the PNG is in place, run this command:

```bash
cd bragging_rights_app
dart run flutter_launcher_icons
```

This will generate all icon sizes for:
- ✅ Android (all densities)
- ✅ Android Adaptive Icons
- ✅ Web
- ✅ Windows

## What You'll Get

Your custom BR icon (Option 3) will be installed as:
- **Android app icon** - all home screen sizes
- **Android adaptive icon** - modern Android with dark blue background
- **Web favicon** and app icons
- **Windows app icon**

## Verify It Worked

After running the command, check:
```bash
ls android/app/src/main/res/mipmap-*/
```

You should see `ic_launcher.png` files in all density folders.

## Next Steps

Once icons are generated, rebuild your app:
```bash
flutter clean
flutter run
```

Your new BR icon will appear on your device! 🎉

---

**Current Icon Design:**
- Dark blue background (matching app theme)
- Gold "B" with dark outline
- White "R" with dark outline
- Gold underline
- Serif font (matching coin logo)
