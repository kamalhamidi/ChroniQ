import 'dart:math';
import 'package:flutter/material.dart';

class ArcTimer extends StatelessWidget {
  final double elapsed;
  final double target;
  final bool isRunning;

  const ArcTimer({
    super.key,
    required this.elapsed,
    required this.target,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _ArcTimerPainter(
          progress: (target <= 0) ? 0 : (elapsed / target).clamp(0.0, 1.0),
        ),
        child: Center(
          child: Text(
            '${elapsed.toStringAsFixed(1)}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontFamily: 'Courier',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcTimerPainter extends CustomPainter {
  final double progress;

  _ArcTimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    final startAngle = -5 * pi / 4; // -225°
    final sweep = 3 * pi / 2; // 270°

    final trackPaint = Paint()
      ..color = const Color(0xFF202025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = _colorForProgress(progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      trackPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep * progress,
      false,
      progressPaint,
    );
  }

  Color _colorForProgress(double t) {
    if (t <= 0.6) {
      return Color.lerp(
            const Color(0xFF00FF88),
            const Color(0xFF00FF88),
            t / 0.6,
          ) ??
          const Color(0xFF00FF88);
    }
    if (t <= 0.85) {
      return Color.lerp(
            const Color(0xFF00FF88),
            const Color(0xFFFFD700),
            (t - 0.6) / 0.25,
          ) ??
          const Color(0xFFFFD700);
    }
    return Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFF3B3B),
          (t - 0.85) / 0.15,
        ) ??
        const Color(0xFFFF3B3B);
  }

  @override
  bool shouldRepaint(covariant _ArcTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
