import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ComboMeter extends StatelessWidget {
  final int combo;

  const ComboMeter({super.key, required this.combo});

  static const Color _unlit = Color(0xFF1A1A2E);
  static const Color _cyan = Color(0xFF00FFFF);
  static const Color _yellow = Color(0xFFFFD700);
  static const Color _orange = Color(0xFFFF6B00);
  static const Color _red = Color(0xFFFF3B3B);

  double get _multiplier {
    if (combo <= 0) return 1.0;
    if (combo == 1) return 1.5;
    if (combo == 2) return 2.0;
    if (combo == 3) return 2.5;
    return 3.0;
  }

  Color _segmentColor(int index) {
    switch (index) {
      case 0:
        return _cyan;
      case 1:
        return _yellow;
      case 2:
        return _orange;
      case 3:
        return _red;
      default:
        return _unlit;
    }
  }

  bool _isLit(int index) {
    if (combo <= 0) return false;
    if (combo == 1) return index == 0;
    if (combo == 2) return index <= 1;
    if (combo == 3) return index <= 2;
    return true;
  }

  String get _multiplierText {
    final m = _multiplier;
    if (m == m.roundToDouble()) return '×${m.toInt()}';
    return '×$m';
  }

  Color get _multiplierColor {
    if (combo <= 0) return _unlit;
    if (combo == 1) return _cyan;
    if (combo == 2) return _yellow;
    if (combo == 3) return _orange;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(4, (index) {
                final lit = _isLit(index);
                final color = lit ? _segmentColor(index) : _unlit;

                Widget segment = Expanded(
                  child: Container(
                    height: 12,
                    margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );

                if (lit) {
                  segment = segment
                      .animate(key: ValueKey('combo-$combo-$index'))
                      .fadeIn(duration: 200.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                        duration: 200.ms,
                        curve: Curves.easeOut,
                      );
                }

                if (lit && index == 3 && combo >= 4) {
                  segment = segment.animate(onPlay: (c) => c.repeat()).scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.05, 1.05),
                        duration: 600.ms,
                        curve: Curves.easeInOut,
                      );
                }

                return segment;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _multiplierText,
            style: TextStyle(
              color: _multiplierColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: combo > 0
                  ? [
                      Shadow(
                        color: _multiplierColor.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
