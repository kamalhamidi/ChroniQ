import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/game_result.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/beat_sequence_display.dart';
import '../widgets/glow_button.dart';

enum _RhythmPhase {
  selectDifficulty,
  showTarget,
  countdown,
  timing,
  nextBeat,
  done,
}

enum RhythmDifficulty { easy, medium, hard }

class RhythmChallengeScreen extends StatefulWidget {
  const RhythmChallengeScreen({super.key});

  @override
  State<RhythmChallengeScreen> createState() => _RhythmChallengeScreenState();
}

class _RhythmChallengeScreenState extends State<RhythmChallengeScreen>
    with TickerProviderStateMixin {
  static const Color _neonPurple = Color(0xFFBF5FFF);

  _RhythmPhase _phase = _RhythmPhase.selectDifficulty;
  RhythmDifficulty? _difficulty;
  int _totalBeats = 3;
  int _currentBeatIndex = 0;
  late List<double> _beatTargets;
  late double _targetTime;
  final List<double> _beatDiffs = [];
  final List<PrecisionTier> _beatTiers = [];
  final List<BeatState> _beatStates = [];

  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();
  final Random _rng = Random();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;

  Timer? _heartbeatCheckTimer;
  Timer? _beatWarningTimer;
  double _elapsedSeconds = 0;
  bool _warningPlayed = false;

  int get _beatCount {
    switch (_difficulty) {
      case RhythmDifficulty.easy:
        return 3;
      case RhythmDifficulty.medium:
        return 4;
      case RhythmDifficulty.hard:
        return 5;
      case null:
        return 3;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _tapScaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tapScaleController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _showDifficultySheet());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapScaleController.dispose();
    _heartbeatCheckTimer?.cancel();
    _beatWarningTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  void _showDifficultySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT DIFFICULTY',
                style: AppTheme.labelStyle.copyWith(
                  color: _neonPurple,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              _difficultyButton(ctx, 'EASY', '3 beats', RhythmDifficulty.easy),
              const SizedBox(height: 12),
              _difficultyButton(ctx, 'MEDIUM', '4 beats', RhythmDifficulty.medium),
              const SizedBox(height: 12),
              _difficultyButton(ctx, 'HARD', '5 beats', RhythmDifficulty.hard),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((_) {
      if (_difficulty == null && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _difficultyButton(
    BuildContext ctx,
    String label,
    String subtitle,
    RhythmDifficulty diff,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(ctx).pop();
        _startGame(diff);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _neonPurple.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _neonPurple.withValues(alpha: 0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.headingSmall.copyWith(
                      color: _neonPurple,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(subtitle, style: AppTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _neonPurple),
          ],
        ),
      ),
    );
  }

  void _startGame(RhythmDifficulty diff) {
    _difficulty = diff;
    _totalBeats = _beatCount;
    _beatTargets = List.generate(_totalBeats, (_) => _generateBeatTarget());
    _beatStates.clear();
    for (int i = 0; i < _totalBeats; i++) {
      _beatStates.add(i == 0 ? BeatState.current : BeatState.upcoming);
    }
    _currentBeatIndex = 0;
    _targetTime = _beatTargets[0];
    setState(() => _phase = _RhythmPhase.showTarget);
  }

  double _generateBeatTarget() {
    while (true) {
      final raw = 100 + _rng.nextInt(900);
      final value = raw / 100.0;
      final hundredths = raw % 100;
      if (hundredths == 0 || hundredths == 50) continue;
      return value;
    }
  }

  void _startCountdown() {
    setState(() => _phase = _RhythmPhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _RhythmPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;
    _warningPlayed = false;
    _audio.startHeartbeat(speed: 0.5);

    _heartbeatCheckTimer?.cancel();
    _beatWarningTimer?.cancel();

    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _phase != _RhythmPhase.timing) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      });

      final ratio = (_elapsedSeconds / _targetTime).clamp(0.0, 2.0);
      _audio.setHeartbeatSpeed(0.5 + ratio * 1.5);

      if (!_warningPlayed && _elapsedSeconds >= _targetTime - 0.3) {
        _warningPlayed = true;
        _audio.playBeatWarning();
      }

      if (_elapsedSeconds >= _targetTime - 0.5 && _elapsedSeconds < _targetTime) {
        _audio.stopHeartbeat();
      }
    });
  }

  void _onTap() {
    if (_phase != _RhythmPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _beatWarningTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;
    final absDiff = (roundedActual - _targetTime).abs();

    _beatDiffs.add(absDiff);
    _beatTiers.add(PrecisionTier.fromDifference(absDiff));
    _beatStates[_currentBeatIndex] =
        absDiff <= 0.150 ? BeatState.hit : BeatState.missed;

    _tapScaleController.forward().then((_) => _tapScaleController.reverse());

    if (_currentBeatIndex >= _totalBeats - 1) {
      setState(() => _phase = _RhythmPhase.done);
      Future.delayed(const Duration(milliseconds: 500), _showResults);
    } else {
      setState(() => _phase = _RhythmPhase.nextBeat);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _currentBeatIndex++;
          _targetTime = _beatTargets[_currentBeatIndex];
          _beatStates[_currentBeatIndex] = BeatState.current;
          _phase = _RhythmPhase.showTarget;
        });
      });
    }
  }

  Future<void> _showResults() async {
    final avgMs = _beatDiffs.reduce((a, b) => a + b) / _beatDiffs.length * 1000;
    final storage = await StorageService.getInstance();
    final previousBest = storage.rhythmBestScore;
    final isNewBest = avgMs < previousBest;
    if (isNewBest) {
      await storage.saveRhythmBestScore(avgMs);
    }
    await storage.addGameResult(avgMs / 1000);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppTheme.fadeRoute(
        _RhythmResultsScreen(
          beatTiers: _beatTiers,
          avgMs: avgMs,
          bestAvgMs: isNewBest ? avgMs : previousBest,
          isNewBest: isNewBest,
          onPlayAgain: () {
            Navigator.of(context).pushReplacement(
              AppTheme.fadeRoute(const RhythmChallengeScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _RhythmPhase.selectDifficulty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cardBg,
                    border: Border.all(
                      color: AppTheme.dimWhite.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppTheme.dimWhite, size: 20),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cardBg,
                        border: Border.all(
                          color: AppTheme.dimWhite.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.dimWhite,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BEAT ${_currentBeatIndex + 1}/$_totalBeats',
                    style: AppTheme.labelStyle.copyWith(
                      color: _neonPurple,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            BeatSequenceDisplay(
              totalBeats: _totalBeats,
              currentBeatIndex: _currentBeatIndex,
              beatStates: _beatStates,
            ),
            const Spacer(),

            if (_phase == _RhythmPhase.showTarget) ...[
              Text(
                'TARGET TIME',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 16),
              Text(
                '${PrecisionCalculator.formatTime(_targetTime)}s',
                style: AppTheme.timerDisplay.copyWith(fontSize: 56),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _startCountdown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: AppTheme.neonGlow(color: _neonPurple),
                  child: Text(
                    'READY',
                    style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                  ),
                ),
              ),
            ],

            if (_phase == _RhythmPhase.countdown)
              CountdownWidget(onComplete: _startTiming),

            if (_phase == _RhythmPhase.timing) ...[
              Text(
                '${_elapsedSeconds.toStringAsFixed(1)}s',
                style: AppTheme.timerDisplay.copyWith(fontSize: 56),
              ),
              const SizedBox(height: 8),
              Text(
                'TARGET ${PrecisionCalculator.formatTime(_targetTime)}s',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.dimWhite.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _onTap,
                child: AnimatedBuilder(
                  animation: _tapScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _tapScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.cardBg,
                          border: Border.all(
                            color: _neonPurple.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _neonPurple.withValues(
                                alpha: _pulseAnimation.value,
                              ),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'TAP',
                            style: AppTheme.headingLarge.copyWith(
                              color: _neonPurple,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            if (_phase == _RhythmPhase.nextBeat)
              Text(
                'NEXT',
                style: AppTheme.countdownDisplay.copyWith(
                  color: _neonPurple,
                  fontSize: 72,
                ),
              ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _RhythmResultsScreen extends StatelessWidget {
  final List<PrecisionTier> beatTiers;
  final double avgMs;
  final double bestAvgMs;
  final bool isNewBest;
  final VoidCallback onPlayAgain;

  const _RhythmResultsScreen({
    required this.beatTiers,
    required this.avgMs,
    required this.bestAvgMs,
    required this.isNewBest,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'RHYTHM RESULTS',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 16),
              Text(
                '${avgMs.toStringAsFixed(0)}ms',
                style: AppTheme.timerDisplay.copyWith(
                  color: const Color(0xFFBF5FFF),
                  fontSize: 56,
                ),
              ),
              Text('AVERAGE DIFF', style: AppTheme.bodyMedium),
              if (isNewBest) ...[
                const SizedBox(height: 8),
                Text(
                  'NEW BEST!',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.amber),
                ),
              ],
              Text(
                'Best: ${bestAvgMs < 999 ? '${bestAvgMs.toStringAsFixed(0)}ms' : '—'}',
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              ...beatTiers.asMap().entries.map((entry) {
                final idx = entry.key;
                final tier = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: tier.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Beat ${idx + 1}',
                          style: AppTheme.bodyLarge,
                        ),
                        const Spacer(),
                        Text(
                          tier.displayName,
                          style: AppTheme.headingSmall.copyWith(
                            color: tier.color,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Spacer(),
              GlowButton(
                text: 'PLAY AGAIN',
                onTap: onPlayAgain,
                color: const Color(0xFFBF5FFF),
              ),
              const SizedBox(height: 12),
              GlowButton(
                text: 'HOME',
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                color: AppTheme.cyan,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
