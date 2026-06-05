import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../utils/precision_calculator.dart';
import '../widgets/gauntlet_hud.dart';
import '../widgets/glow_button.dart';

enum _GauntletPhase { ready, timing, flash, sessionEnd }

class ReflexGauntletScreen extends StatefulWidget {
  const ReflexGauntletScreen({super.key});

  @override
  State<ReflexGauntletScreen> createState() => _ReflexGauntletScreenState();
}

class _ReflexGauntletScreenState extends State<ReflexGauntletScreen>
    with TickerProviderStateMixin {
  static const Color _neonOrange = Color(0xFFFF6B00);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonRed = Color(0xFFFF3B3B);
  static const double _sessionDuration = 60.0;

  _GauntletPhase _phase = _GauntletPhase.ready;
  late double _targetTime;
  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();
  final Random _rng = Random();

  double _sessionRemaining = _sessionDuration;
  int _roundsAttempted = 0;
  int _hits = 0;
  double _bestPrecision = 999.0;
  final List<bool> _lastResults = [];
  bool? _lastFlashHit;
  int _flashKey = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;

  Timer? _sessionTimer;
  Timer? _heartbeatCheckTimer;
  Timer? _roundDelayTimer;
  double _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _targetTime = _generateGauntletTarget();

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapScaleController.dispose();
    _sessionTimer?.cancel();
    _heartbeatCheckTimer?.cancel();
    _roundDelayTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  double _generateGauntletTarget() {
    while (true) {
      final raw = 100 + _rng.nextInt(401);
      final value = raw / 100.0;
      final hundredths = raw % 100;
      if (hundredths == 0 || hundredths == 50) continue;
      return value;
    }
  }

  void _startSession() {
    _sessionRemaining = _sessionDuration;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _sessionRemaining -= 0.1;
      });
      if (_sessionRemaining <= 0) {
        timer.cancel();
        _endSession();
      }
    });
    _startRound();
  }

  void _startRound() {
    setState(() => _phase = _GauntletPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;
    _audio.startHeartbeat(speed: 0.7);

    _heartbeatCheckTimer?.cancel();
    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _GauntletPhase.timing) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      });

      final ratio = (_elapsedSeconds / _targetTime).clamp(0.0, 2.0);
      _audio.setHeartbeatSpeed(0.7 + ratio * 1.3);

      if (_elapsedSeconds >= _targetTime - 0.5 && _elapsedSeconds < _targetTime) {
        _audio.stopHeartbeat();
      }
    });
  }

  void _onTap() {
    if (_phase == _GauntletPhase.ready) {
      _startSession();
      return;
    }
    if (_phase != _GauntletPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;
    final absDiff = (roundedActual - _targetTime).abs();
    final isHit = absDiff <= 0.150;

    _roundsAttempted++;
    if (isHit) _hits++;
    if (absDiff < _bestPrecision) _bestPrecision = absDiff;

    _lastResults.add(isHit);
    if (_lastResults.length > 5) _lastResults.removeAt(0);

    _tapScaleController.forward().then((_) => _tapScaleController.reverse());

    setState(() {
      _phase = _GauntletPhase.flash;
      _lastFlashHit = isHit;
      _flashKey++;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _sessionRemaining <= 0) return;
      _targetTime = _generateGauntletTarget();
      _roundDelayTimer?.cancel();
      _roundDelayTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted || _sessionRemaining <= 0) return;
        _startRound();
      });
    });
  }

  Future<void> _endSession() async {
    _heartbeatCheckTimer?.cancel();
    _roundDelayTimer?.cancel();
    _audio.stopHeartbeat();
    setState(() => _phase = _GauntletPhase.sessionEnd);

    final storage = await StorageService.getInstance();
    final previousHigh = storage.gauntletHighScore;
    final isNewHigh = _hits > previousHigh;
    if (isNewHigh) {
      await storage.saveGauntletHighScore(_hits);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppTheme.fadeRoute(
        _GauntletResultsScreen(
          roundsAttempted: _roundsAttempted,
          hits: _hits,
          bestPrecision: _bestPrecision,
          highScore: isNewHigh ? _hits : previousHigh,
          isNewHigh: isNewHigh,
          onPlayAgain: () {
            Navigator.of(context).pushReplacement(
              AppTheme.fadeRoute(const ReflexGauntletScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Stack(
          children: [
            if (_phase == _GauntletPhase.flash && _lastFlashHit != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    key: ValueKey('flash-$_flashKey'),
                    color: (_lastFlashHit! ? _neonGreen : _neonRed)
                        .withValues(alpha: 0.3),
                  )
                      .animate()
                      .fadeOut(duration: 300.ms, curve: Curves.easeOut),
                ),
              ),

            Column(
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
                    ],
                  ),
                ),

                if (_phase != _GauntletPhase.ready)
                  GauntletHUD(
                    sessionSecondsRemaining: _sessionRemaining.clamp(0, _sessionDuration),
                    targetTime: _targetTime,
                    hitCount: _hits,
                    lastResults: _lastResults,
                  ),

                const Spacer(),

                if (_phase == _GauntletPhase.ready) ...[
                  Text(
                    'REFLEX GAUNTLET',
                    style: AppTheme.labelStyle.copyWith(
                      color: _neonOrange,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '60s',
                    style: AppTheme.timerDisplay.copyWith(
                      color: _neonOrange,
                      fontSize: 72,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${PrecisionCalculator.formatTime(_targetTime)}s',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: AppTheme.neonGlow(color: _neonOrange),
                      child: Text(
                        'READY',
                        style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                      ),
                    ),
                  ),
                ],

                if (_phase == _GauntletPhase.timing ||
                    _phase == _GauntletPhase.flash) ...[
                  Text(
                    '${_elapsedSeconds.toStringAsFixed(1)}s',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.dimWhite.withValues(alpha: 0.5),
                      fontSize: 24,
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
                                color: _neonOrange.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonOrange.withValues(
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
                                  color: _neonOrange,
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

                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GauntletResultsScreen extends StatelessWidget {
  final int roundsAttempted;
  final int hits;
  final double bestPrecision;
  final int highScore;
  final bool isNewHigh;
  final VoidCallback onPlayAgain;

  const _GauntletResultsScreen({
    required this.roundsAttempted,
    required this.hits,
    required this.bestPrecision,
    required this.highScore,
    required this.isNewHigh,
    required this.onPlayAgain,
  });

  String _grade(double rate) {
    if (rate >= 0.8) return 'S';
    if (rate >= 0.6) return 'A';
    if (rate >= 0.4) return 'B';
    return 'C';
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':
        return const Color(0xFFFFD700);
      case 'A':
        return const Color(0xFF00FF88);
      case 'B':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFFFF3B3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hitRate = roundsAttempted > 0 ? hits / roundsAttempted : 0.0;
    final grade = _grade(hitRate);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'GAUNTLET COMPLETE',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 24),
              Text(
                grade,
                style: AppTheme.timerDisplay.copyWith(
                  color: _gradeColor(grade),
                  fontSize: 96,
                ),
              ),
              Text('GRADE', style: AppTheme.bodyMedium),
              const SizedBox(height: 32),
              _row('ROUNDS', '$roundsAttempted'),
              _row('HITS', '$hits'),
              _row('HIT RATE', '${(hitRate * 100).toStringAsFixed(0)}%'),
              _row(
                'BEST PRECISION',
                bestPrecision < 999
                    ? '±${bestPrecision.toStringAsFixed(3)}s'
                    : '—',
              ),
              _row(
                'HIGH SCORE',
                '$highScore${isNewHigh ? ' 👑' : ''}',
              ),
              const Spacer(),
              GlowButton(
                text: 'PLAY AGAIN',
                onTap: onPlayAgain,
                color: const Color(0xFFFF6B00),
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(
            value,
            style: AppTheme.headingSmall.copyWith(letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
