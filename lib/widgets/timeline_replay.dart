import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../models/game_result.dart';

class TimelineReplay extends StatefulWidget {
  final double targetTime;
  final double actualTime;
  final PrecisionTier tier;

  const TimelineReplay({
    super.key,
    required this.targetTime,
    required this.actualTime,
    required this.tier,
  });

  @override
  State<TimelineReplay> createState() => _TimelineReplayState();
}

class _TimelineReplayState extends State<TimelineReplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _dotPosition;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    final maxTime = widget.targetTime * 1.5;
    final targetRatio = (widget.actualTime / maxTime).clamp(0.0, 1.0);

    _dotPosition = Tween<double>(begin: 0.0, end: targetRatio).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _dotController.forward();
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: AnimatedBuilder(
        animation: _dotPosition,
        builder: (context, _) {
          return CustomPaint(
            painter: _TimelinePainter(
              targetTime: widget.targetTime,
              actualTime: widget.actualTime,
              dotProgress: _dotPosition.value,
              tier: widget.tier,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double targetTime;
  final double actualTime;
  final double dotProgress;
  final PrecisionTier tier;

  _TimelinePainter({
    required this.targetTime,
    required this.actualTime,
    required this.dotProgress,
    required this.tier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxTime = targetTime * 1.5;
    final lineY = size.height * 0.55;
    final lineStart = 20.0;
    final lineEnd = size.width - 20.0;
    final lineWidth = lineEnd - lineStart;

    // ── Background line ──
    final linePaint = Paint()
      ..color = AppTheme.dimWhite.withValues(alpha: 0.2)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(lineStart, lineY),
      Offset(lineEnd, lineY),
      linePaint,
    );

    // ── Target marker ──
    final targetX = lineStart + (targetTime / maxTime) * lineWidth;
    final targetPaint = Paint()
      ..color = AppTheme.purple
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(targetX, lineY - 18),
      Offset(targetX, lineY + 18),
      targetPaint,
    );

    // Target glow
    final targetGlowPaint = Paint()
      ..color = AppTheme.purple.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(targetX, lineY - 16),
      Offset(targetX, lineY + 16),
      targetGlowPaint,
    );

    // Target label
    final targetLabelPainter = TextPainter(
      text: TextSpan(
        text: '${targetTime.toStringAsFixed(2)}s',
        style: TextStyle(
          color: AppTheme.purple,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    targetLabelPainter.paint(
      canvas,
      Offset(targetX - targetLabelPainter.width / 2, lineY - 32),
    );

    // ── Player tap dot ──
    final dotX = lineStart + dotProgress * lineWidth;
    final dotColor = tier.color;

    // Dot glow
    final dotGlowPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(dotX, lineY), 8, dotGlowPaint);

    // Dot fill
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(dotX, lineY), 6, dotPaint);

    // Dot inner
    final dotInnerPaint = Paint()..color = AppTheme.white;
    canvas.drawCircle(Offset(dotX, lineY), 2.5, dotInnerPaint);

    // Player label (only show when animation is mostly done)
    if (dotProgress > 0.8) {
      final playerLabelPainter = TextPainter(
        text: TextSpan(
          text: '${actualTime.toStringAsFixed(2)}s',
          style: TextStyle(
            color: dotColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      // Avoid overlapping with target label
      final labelX = dotX - playerLabelPainter.width / 2;
      final labelY = (dotX - targetX).abs() < 30 ? lineY + 22 : lineY + 22;
      playerLabelPainter.paint(canvas, Offset(labelX, labelY));
    }

    // ── Time markers ──
    for (int i = 0; i <= math.max(targetTime.ceil(), actualTime.ceil()); i++) {
      final x = lineStart + (i / maxTime) * lineWidth;
      if (x > lineEnd) break;
      
      final tickPaint = Paint()
        ..color = AppTheme.dimWhite.withValues(alpha: 0.15)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, lineY + 8), Offset(x, lineY + 14), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return dotProgress != oldDelegate.dotProgress;
  }
}
