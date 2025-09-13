import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class NeonButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;
  final double? width;
  final double height;
  final bool isLoading;
  final bool isDisabled;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.width,
    this.height = 50,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? AppTheme.primaryCyan;
    final isDisabled = widget.isDisabled || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDisabled
                    ? [Colors.grey.shade700, Colors.grey.shade800]
                    : [
                        buttonColor,
                        buttonColor.withOpacity(0.8),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: buttonColor.withOpacity(
                          0.3 + (_glowController.value * 0.3),
                        ),
                        blurRadius: 20 + (_glowController.value * 10),
                        spreadRadius: _isPressed ? 5 : 0,
                      ),
                      BoxShadow(
                        color: buttonColor.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: isDisabled ? null : widget.onPressed,
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.deepBlue,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : AppTheme.deepBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : AppTheme.deepBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: isDisabled
                                    ? []
                                    : [
                                        Shadow(
                                          color: Colors.white.withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(),
          ).shimmer(
            duration: 3000.ms,
            color: isDisabled ? Colors.transparent : Colors.white.withOpacity(0.1),
          );
        },
      ),
    ).animate().scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1, 1),
      duration: 200.ms,
    );
  }
}