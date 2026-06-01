import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class GlitchOverlay extends StatefulWidget {
  const GlitchOverlay({super.key});

  @override
  State<GlitchOverlay> createState() => _GlitchOverlayState();
}

class _GlitchOverlayState extends State<GlitchOverlay> {
  final Random _rng = Random();
  Timer? _timer;
  Timer? _stopTimer;
  List<_GlitchLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _generateLines();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(_generateLines);
    });
    _stopTimer = Timer(const Duration(milliseconds: 500), () {
      _timer?.cancel();
    });
  }

  void _generateLines() {
    final count = 3 + _rng.nextInt(3);
    _lines = List.generate(count, (_) {
      final height = 2.0 + _rng.nextDouble() * 6.0;
      return _GlitchLine(
        y: _rng.nextDouble(),
        height: height,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlitchPainter(lines: _lines),
      child: const SizedBox.expand(),
    );
  }
}

class _GlitchLine {
  final double y;
  final double height;

  _GlitchLine({required this.y, required this.height});
}

class _GlitchPainter extends CustomPainter {
  final List<_GlitchLine> lines;

  _GlitchPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF3B3B).withOpacity(0.15);
    for (final line in lines) {
      final top = line.y * size.height;
      final rect = Rect.fromLTWH(0, top, size.width, line.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) {
    return oldDelegate.lines != lines;
  }
}
