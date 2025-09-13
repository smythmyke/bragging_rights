import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  // Neon Cyber Color Palette
  static const Color primaryCyan = Color(0xFF00D9FF);
  static const Color secondaryCyan = Color(0xFF0099FF);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color deepBlue = Color(0xFF0A0E27);
  static const Color surfaceBlue = Color(0xFF1A1F3A);
  static const Color cardBlue = Color(0xFF141829);
  static const Color borderCyan = Color(0xFF00D9FF);
  static const Color errorPink = Color(0xFFFF0066);
  static const Color warningAmber = Color(0xFFFFB700);
  static const Color successGreen = Color(0xFF00FF88);
  
  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, secondaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [deepBlue, surfaceBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [neonGreen, primaryCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Glow effects
  static BoxShadow glowShadow({
    Color color = primaryCyan,
    double radius = 20,
    double opacity = 0.5,
  }) {
    return BoxShadow(
      color: color.withOpacity(opacity),
      blurRadius: radius,
      spreadRadius: 0,
    );
  }
  
  static List<BoxShadow> neonGlow({
    Color color = primaryCyan,
    double intensity = 1.0,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(0.5 * intensity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 40,
        spreadRadius: 0,
      ),
    ];
  }
  
  // Text styles
  static TextStyle neonText({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color color = primaryCyan,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: [
        Shadow(
          color: color.withOpacity(0.8),
          blurRadius: 10,
        ),
      ],
    );
  }
  
  // Light theme (with dark elements for contrast)
  static ThemeData lightTheme = FlexThemeData.light(
    scheme: FlexScheme.blueM3,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 15,
    appBarStyle: FlexAppBarStyle.surface,
    appBarOpacity: 0.95,
    appBarElevation: 0,
    transparentStatusBar: true,
    tabBarStyle: FlexTabBarStyle.universal,
    tooltipsMatchBackground: true,
    swapColors: false,
    lightIsWhite: false,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    fontFamily: 'Roboto',
    subThemesData: const FlexSubThemesData(
      useTextTheme: true,
      useM2StyleDividerInM3: true,
      elevatedButtonSchemeColor: SchemeColor.primary,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      toggleButtonsBorderSchemeColor: SchemeColor.primary,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonBorderSchemeColor: SchemeColor.primary,
      unselectedToggleIsColored: true,
      sliderValueTinted: true,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorBackgroundAlpha: 31,
      inputDecoratorRadius: 8.0,
      inputDecoratorUnfocusedHasBorder: true,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      popupMenuRadius: 10,
      popupMenuElevation: 8,
      drawerIndicatorRadius: 12,
      drawerIndicatorSchemeColor: SchemeColor.primary,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 10,
      menuElevation: 8,
      menuBarRadius: 0,
      menuBarElevation: 1,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarMutedUnselectedLabel: false,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarMutedUnselectedIcon: false,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarIndicatorOpacity: 1.0,
      navigationBarIndicatorRadius: 12,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailMutedUnselectedLabel: false,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailMutedUnselectedIcon: false,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.0,
      navigationRailIndicatorRadius: 12,
    ),
  ).copyWith(
    primaryColor: primaryCyan,
    scaffoldBackgroundColor: deepBlue,
    cardColor: cardBlue,
    dividerColor: borderCyan.withOpacity(0.2),
  );
  
  // Dark theme (Neon Cyber)
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryCyan,
    scaffoldBackgroundColor: deepBlue,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: secondaryCyan,
      surface: surfaceBlue,
      error: errorPink,
      onPrimary: deepBlue,
      onSecondary: deepBlue,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: deepBlue,
      elevation: 0,
      titleTextStyle: neonText(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: primaryCyan),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryCyan,
        foregroundColor: deepBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      color: cardBlue,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceBlue.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCyan.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCyan.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryCyan, width: 2),
      ),
      labelStyle: const TextStyle(color: primaryCyan),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: borderCyan.withOpacity(0.2),
      thickness: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBlue,
      selectedItemColor: primaryCyan,
      unselectedItemColor: Colors.white.withOpacity(0.5),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
  
  // Custom widget themes
  static BoxDecoration glassContainer({
    Color? color,
    double borderRadius = 12,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: (color ?? surfaceBlue).withOpacity(0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(
              color: borderCyan.withOpacity(0.3),
              width: 1,
            )
          : null,
      boxShadow: neonGlow(intensity: 0.3),
    );
  }
  
  static BoxDecoration neonButton({
    Color color = primaryCyan,
    double borderRadius = 8,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: neonGlow(color: color),
    );
  }
  
  static BoxDecoration liveIndicator() {
    return BoxDecoration(
      color: neonGreen,
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: neonGreen.withOpacity(0.8),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }
}