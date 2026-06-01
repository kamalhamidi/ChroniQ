import 'dart:math';
import 'package:flutter/material.dart';

class TimingDial extends StatefulWidget {
  final double playerTime;
  final double targetTime;

  const TimingDial({
    super.key,
    required this.playerTime,
    required this.targetTime,
  });

  @override
  State<TimingDial> createState() => _TimingDialState();
}

class _TimingDialState extends State<TimingDial>
    with TickerProviderStateMixin {
  late final AnimationController _needleController;
  late final Animation<double> _playerAngle;
  late final AnimationController _targetFadeController;

  @override
  void initState() {
    super.initState();

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _targetFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    final targetAngle = _timeToAngle(widget.playerTime);
    _playerAngle = Tween<double>(
      begin: -pi / 2,
      end: targetAngle,
    ).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.elasticOut),
    );

    _needleController.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _targetFadeController.forward();
      });
    });
  }

  @override
  void dispose() {
    _needleController.dispose();
    _targetFadeController.dispose();
    super.dispose();
  }

  double _timeToAngle(double time) {
    final clamped = time.clamp(0.0, 10.0);
    return -pi / 2 + (clamped / 10.0) * 2 * pi;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: Listenable.merge([_needleController, _targetFadeController]),
        builder: (context, _) {
          return CustomPaint(
            painter: _TimingDialPainter(
              playerAngle: _playerAngle.value,
              targetAngle: _timeToAngle(widget.targetTime),
              targetOpacity: _targetFadeController.value,
            ),
          );
        },
      ),
    );
  }
}

class _TimingDialPainter extends CustomPainter {
  final double playerAngle;
  final double targetAngle;
  final double targetOpacity;

  _TimingDialPainter({
    required this.playerAngle,
    required this.targetAngle,
    required this.targetOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final ringPaint = Paint()
      ..color = const Color(0xFF1C1C22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, ringPaint);

    _drawTicks(canvas, center, radius);
    _drawLabels(canvas, center, radius + 8);

    _drawNeedle(
      canvas,
      center,
      radius - 8,
      playerAngle,
      color: const Color(0xFF00FF88),
      width: 3,
      dashed: false,
    );

    _drawNeedle(
      canvas,
      center,
      radius - 8,
      targetAngle,
      color: const Color(0xFFBF5FFF).withOpacity(0.5 * targetOpacity),
      width: 2,
      dashed: true,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = const Color(0xFF4A4A55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 10; i++) {
      final angle = -pi / 2 + (i / 10) * 2 * pi;
      final inner = Offset(
        center.dx + cos(angle) * (radius - 8),
        center.dy + sin(angle) * (radius - 8),
      );
      final outer = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    const labels = [0, 3, 6, 9];
    for (final value in labels) {
      final angle = -pi / 2 + (value / 10) * 2 * pi;
      final offset = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(offset.dx - textPainter.width / 2, offset.dy - textPainter.height / 2),
      );
    }
  }

  void _drawNeedle(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    {
    required Color color,
    required double width,
    required bool dashed,
  }) {
    final end = Offset(
      center.dx + cos(angle) * length,
      center.dy + sin(angle) * length,
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(center, end, paint);
      return;
    }

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(end.dx, end.dy);

    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      const dashLength = 6.0;
      const gapLength = 4.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          min(distance + dashLength, metric.length),
        );
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimingDialPainter oldDelegate) {
    return oldDelegate.playerAngle != playerAngle ||
        oldDelegate.targetAngle != targetAngle ||
        oldDelegate.targetOpacity != targetOpacity;
  }
}
