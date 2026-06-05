import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../utils/precision_calculator.dart';

class GauntletHUD extends StatelessWidget {
  final double sessionSecondsRemaining;
  final double targetTime;
  final int hitCount;
  final List<bool> lastResults;

  const GauntletHUD({
    super.key,
    required this.sessionSecondsRemaining,
    required this.targetTime,
    required this.hitCount,
    required this.lastResults,
  });

  static const Color _neonYellow = Color(0xFFFFD700);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonRed = Color(0xFFFF3B3B);
  static const Color _neonOrange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final isUrgent = sessionSecondsRemaining <= 10;
    final timerColor = isUrgent ? _neonRed : _neonYellow;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildTimer(sessionSecondsRemaining, timerColor, isUrgent),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '${PrecisionCalculator.formatTime(targetTime)}s',
                    style: AppTheme.timerDisplay.copyWith(
                      fontSize: 40,
                      color: _neonOrange,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$hitCount HITS',
                    style: AppTheme.headingSmall.copyWith(
                      color: _neonGreen,
                      letterSpacing: 1,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: lastResults.asMap().entries.map((entry) {
              final isHit = entry.value;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHit ? _neonGreen : _neonRed,
                    boxShadow: [
                      BoxShadow(
                        color: (isHit ? _neonGreen : _neonRed).withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                )
                    .animate(key: ValueKey('dot-${entry.key}-${lastResults.length}'))
                    .slideX(begin: 1.0, end: 0.0, duration: 200.ms, curve: Curves.easeOut)
                    .fadeIn(duration: 200.ms),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(double seconds, Color color, bool urgent) {
    final text = Text(
      '${seconds.ceil()}s',
      style: AppTheme.headingLarge.copyWith(
        color: color,
        fontSize: 28,
        shadows: urgent
            ? [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12)]
            : null,
      ),
    );

    if (urgent) {
      return text
          .animate(onPlay: (c) => c.repeat())
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.08, 1.08),
            duration: 500.ms,
            curve: Curves.easeInOut,
          );
    }
    return text;
  }
}
