import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/precision_calculator.dart';

class ZoneHintBar extends StatelessWidget {
  final double targetTime;
  final double zoneLower;
  final double zoneUpper;
  final bool revealed;
  final bool collapsed;

  const ZoneHintBar({
    super.key,
    required this.targetTime,
    required this.zoneLower,
    required this.zoneUpper,
    this.revealed = false,
    this.collapsed = false,
  });

  static const Color _trackColor = Color(0xFF1A1A2E);
  static const Color _neonCyan = Color(0xFF00FFFF);
  static const double _trackMax = 10.0;
  static const double _barHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final zoneLeft = (zoneLower / _trackMax) * trackWidth;
        final zoneRight = (zoneUpper / _trackMax) * trackWidth;
        final zoneWidth = (zoneRight - zoneLeft).clamp(0.0, trackWidth);

        final targetLeft = (targetTime / _trackMax) * trackWidth;
        final collapsedWidth = 2.0;
        final displayLeft = collapsed ? targetLeft - collapsedWidth / 2 : zoneLeft;
        final displayWidth = collapsed ? collapsedWidth : zoneWidth;

        return Column(
          children: [
            if (revealed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'TARGET: ${PrecisionCalculator.formatTime(targetTime)}s',
                  style: const TextStyle(
                    color: _neonCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              height: _barHeight,
              decoration: BoxDecoration(
                color: _trackColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _neonCyan.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      left: displayLeft,
                      top: 0,
                      bottom: 0,
                      width: displayWidth,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: collapsed ? 0 : 4, sigmaY: collapsed ? 0 : 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _neonCyan.withValues(alpha: collapsed ? 1.0 : 0.2),
                              border: Border.all(
                                color: _neonCyan.withValues(alpha: 0.6),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonCyan.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!collapsed) ...[
                      Positioned(
                        left: zoneLeft + 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '${zoneLower.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: trackWidth - zoneRight + 4,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '${zoneUpper.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!revealed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Target is between ${zoneLower.toStringAsFixed(1)}s and ${zoneUpper.toStringAsFixed(1)}s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
