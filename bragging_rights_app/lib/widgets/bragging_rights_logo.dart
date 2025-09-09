import 'package:flutter/material.dart';

class BraggingRightsLogo extends StatelessWidget {
  final double height;
  final bool showUnderline;
  final bool animate;
  
  const BraggingRightsLogo({
    super.key,
    this.height = 100,
    this.showUnderline = true,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Image.asset(
        'assets/images/bragging_rights_logo.png',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

class UnderlinePainter extends CustomPainter {
  final bool animate;
  
  UnderlinePainter({this.animate = false});
  
  @override
  void paint(Canvas canvas, Size size) {
    // White line paint
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Yellow line paint
    final yellowPaint = Paint()
      ..color = const Color(0xFFFFD700) // Gold yellow
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Accent paint for dots/dashes
    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;
    
    // Draw staggered white line (upper)
    final whitePath = Path();
    whitePath.moveTo(0, size.height * 0.3);
    
    // Create a wavy/staggered effect
    for (double i = 0; i <= size.width; i += size.width / 8) {
      final y = size.height * 0.3 + (i.toInt() % 2 == 0 ? -2 : 2);
      if (i == 0) {
        whitePath.moveTo(i, y);
      } else {
        whitePath.lineTo(i, y);
      }
    }
    
    canvas.drawPath(whitePath, whitePaint);
    
    // Draw staggered yellow line (lower)
    final yellowPath = Path();
    yellowPath.moveTo(size.width * 0.05, size.height * 0.6);
    
    for (double i = size.width * 0.05; i <= size.width * 0.95; i += size.width / 10) {
      final y = size.height * 0.6 + (i.toInt() % 2 == 0 ? 2 : -2);
      if (i == size.width * 0.05) {
        yellowPath.moveTo(i, y);
      } else {
        yellowPath.lineTo(i, y);
      }
    }
    
    canvas.drawPath(yellowPath, yellowPaint);
    
    // Add accent dots at intervals
    for (double i = 0; i <= size.width; i += size.width / 5) {
      // White accent dots
      canvas.drawCircle(
        Offset(i, size.height * 0.3),
        1.5,
        accentPaint,
      );
      
      // Yellow accent dots with slight offset
      if (i > size.width * 0.05 && i < size.width * 0.95) {
        canvas.drawCircle(
          Offset(i + size.width * 0.02, size.height * 0.6),
          1.5,
          accentPaint..color = const Color(0xFFFFD700).withOpacity(0.9),
        );
      }
    }
    
    // Add small diagonal accent lines
    final accentLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Left accent
    canvas.drawLine(
      Offset(-5, size.height * 0.45),
      Offset(10, size.height * 0.35),
      accentLinePaint,
    );
    
    // Right accent
    canvas.drawLine(
      Offset(size.width - 10, size.height * 0.35),
      Offset(size.width + 5, size.height * 0.45),
      accentLinePaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return animate;
  }
}

// Animated version of the logo
class AnimatedBraggingRightsLogo extends StatefulWidget {
  final double height;
  
  const AnimatedBraggingRightsLogo({
    super.key,
    this.height = 100,
  });
  
  @override
  State<AnimatedBraggingRightsLogo> createState() => _AnimatedBraggingRightsLogoState();
}

class _AnimatedBraggingRightsLogoState extends State<AnimatedBraggingRightsLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -50,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeIn),
    ));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Image.asset(
            'assets/images/bragging_rights_logo.png',
            height: widget.height,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}