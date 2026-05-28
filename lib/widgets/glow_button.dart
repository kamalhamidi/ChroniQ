import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final double width;
  final double height;
  final double fontSize;
  final bool enabled;

  const GlowButton({
    super.key,
    required this.text,
    required this.onTap,
    this.color = AppTheme.purple,
    this.width = double.infinity,
    this.height = 56,
    this.fontSize = 16,
    this.enabled = true,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.enabled ? widget.color : widget.color.withValues(alpha: 0.3);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: widget.enabled
            ? (_) {
                setState(() => _isPressed = true);
                _controller.forward();
              }
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _isPressed = false);
                _controller.reverse();
                widget.onTap();
              }
            : null,
        onTapCancel: widget.enabled
            ? () {
                setState(() => _isPressed = false);
                _controller.reverse();
              }
            : null,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _isPressed
                ? effectiveColor.withValues(alpha: 0.2)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: effectiveColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveColor.withValues(alpha: _isPressed ? 0.8 : 0.4),
                blurRadius: _isPressed ? 30 : 16,
                spreadRadius: _isPressed ? 4 : 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: AppTheme.headingSmall.copyWith(
                fontSize: widget.fontSize,
                color: widget.enabled ? AppTheme.white : AppTheme.dimWhite,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
