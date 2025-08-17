import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphismContainer extends StatelessWidget {
  final double blur;
  final double opacity;
  final Widget child;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;

  const GlassmorphismContainer({
    Key? key,
    required this.blur,
    required this.opacity,
    required this.child,
    this.borderRadius,
    this.border,
    this.padding,
    this.width,
    this.height,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(opacity),
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassmorphicTheme {
  static const Color primaryGlass = Color(0x1AFFFFFF);
  static const Color secondaryGlass = Color(0x0DFFFFFF);
  static const Color accentGlass = Color(0x26FFFFFF);
  
  static const double defaultBlur = 10.0;
  static const double lightBlur = 5.0;
  static const double heavyBlur = 20.0;
  
  static const double defaultOpacity = 0.1;
  static const double lightOpacity = 0.05;
  static const double mediumOpacity = 0.15;
  static const double heavyOpacity = 0.25;
  
  static Border glassBorder({
    Color? color,
    double width = 1.0,
  }) {
    return Border.all(
      color: color ?? Colors.white.withOpacity(0.2),
      width: width,
    );
  }
  
  static BoxDecoration glassDecoration({
    double blur = defaultBlur,
    double opacity = defaultOpacity,
    BorderRadius? borderRadius,
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      border: border ?? glassBorder(),
    );
  }
  
  static Widget glassCard({
    required Widget child,
    double blur = defaultBlur,
    double opacity = defaultOpacity,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      margin: margin,
      child: GlassmorphismContainer(
        blur: blur,
        opacity: opacity,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: glassBorder(),
        padding: padding ?? const EdgeInsets.all(16),
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}

class GlassmorphicButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final Color? color;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Widget? icon;

  const GlassmorphicButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.textStyle,
    this.color,
    this.blur = GlassmorphicTheme.lightBlur,
    this.opacity = GlassmorphicTheme.mediumOpacity,
    this.borderRadius,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassmorphismContainer(
      blur: blur,
      opacity: opacity,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      border: GlassmorphicTheme.glassBorder(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: Center(
              child: icon != null 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon!,
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: textStyle ?? const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: textStyle ?? const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassmorphicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double blur;
  final double opacity;
  final double elevation;
  final Color? backgroundColor;

  const GlassmorphicAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.blur = GlassmorphicTheme.defaultBlur,
    this.opacity = GlassmorphicTheme.defaultOpacity,
    this.elevation = 0,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: (backgroundColor ?? Colors.white).withOpacity(opacity),
          elevation: elevation,
          leading: leading,
          actions: actions,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}