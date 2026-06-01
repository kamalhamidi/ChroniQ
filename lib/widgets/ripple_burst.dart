import 'dart:math';
import 'package:flutter/material.dart';

class RippleBurst extends StatefulWidget {
  final int ringCount;

  const RippleBurst({super.key, this.ringCount = 5});

  @override
  State<RippleBurst> createState() => _RippleBurstState();
}

class _RippleBurstState extends State<RippleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
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
      builder: (context, _) {
        return CustomPaint(
          painter: _RippleBurstPainter(
            progress: _controller.value,
            ringCount: widget.ringCount,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RippleBurstPainter extends CustomPainter {
  final double progress;
  final int ringCount;

  _RippleBurstPainter({
    required this.progress,
    required this.ringCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;
    const delayStep = 0.12; // 120ms across 1.2s total

    for (int i = 0; i < ringCount; i++) {
      final t = ((progress - (i * delayStep)) / (1 - delayStep))
          .clamp(0.0, 1.0);
      if (t <= 0) continue;

      final radius = maxRadius * t;
      final alpha = (1.0 - t) * 0.6;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00FFFF).withOpacity(alpha),
            const Color(0x0000FFFF),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RippleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ringCount != ringCount;
  }
}
