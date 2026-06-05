import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum BeatState { upcoming, current, hit, missed }

class BeatSequenceDisplay extends StatelessWidget {
  final int totalBeats;
  final int currentBeatIndex;
  final List<BeatState> beatStates;

  const BeatSequenceDisplay({
    super.key,
    required this.totalBeats,
    required this.currentBeatIndex,
    required this.beatStates,
  });

  static const Color _neonPurple = Color(0xFFBF5FFF);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonRed = Color(0xFFFF3B3B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalBeats, (index) {
          final state = beatStates.length > index
              ? beatStates[index]
              : BeatState.upcoming;
          return Padding(
            padding: EdgeInsets.only(right: index < totalBeats - 1 ? 12 : 0),
            child: _buildBeatCircle(index, state),
          );
        }),
      ),
    );
  }

  Widget _buildBeatCircle(int index, BeatState state) {
    const size = 36.0;

    Widget circle;

    switch (state) {
      case BeatState.upcoming:
        circle = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _neonPurple, width: 2),
          ),
        );
        break;

      case BeatState.current:
        circle = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neonPurple,
            boxShadow: [
              BoxShadow(
                color: _neonPurple.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.15, 1.15),
              duration: 800.ms,
              curve: Curves.easeInOut,
            );
        break;

      case BeatState.hit:
        circle = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neonGreen,
            boxShadow: [
              BoxShadow(
                color: _neonGreen.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        )
            .animate(key: ValueKey('hit-$index'))
            .fadeIn(duration: 200.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
            );
        break;

      case BeatState.missed:
        circle = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neonRed,
            boxShadow: [
              BoxShadow(
                color: _neonRed.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        )
            .animate(key: ValueKey('miss-$index'))
            .fadeIn(duration: 200.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
            );
        break;
    }

    return circle;
  }
}
