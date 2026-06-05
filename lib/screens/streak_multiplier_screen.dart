import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/game_result.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/arc_timer.dart';
import '../widgets/combo_meter.dart';
import '../widgets/glow_button.dart';

enum _StreakPhase { showTarget, countdown, timing, done }

class StreakMultiplierScreen extends StatefulWidget {
  const StreakMultiplierScreen({super.key});

  @override
  State<StreakMultiplierScreen> createState() => _StreakMultiplierScreenState();
}

class _StreakMultiplierScreenState extends State<StreakMultiplierScreen>
    with TickerProviderStateMixin {
  static const int _totalRounds = 10;
  static const Color _neonCyan = Color(0xFF00FFFF);

  _StreakPhase _phase = _StreakPhase.showTarget;
  int _currentRound = 1;
  int _combo = 0;
  int _bestCombo = 0;
  int _totalScore = 0;
  late double _targetTime;

  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _edgeGlowController;
  late Animation<double> _edgeGlowAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;
  late AnimationController _screenPulseController;
  late Animation<double> _screenPulseAnimation;

  Timer? _heartbeatCheckTimer;
  double _elapsedSeconds = 0;

  double get _comboMultiplier {
    if (_combo <= 0) return 1.0;
    if (_combo == 1) return 1.5;
    if (_combo == 2) return 2.0;
    if (_combo == 3) return 2.5;
    return 3.0;
  }

  double get _vignetteOpacity {
    if (_combo >= 4) return 0.25;
    if (_combo >= 2) return 0.10;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _targetTime = PrecisionCalculator.generateTarget();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _edgeGlowController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _edgeGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _edgeGlowController, curve: Curves.easeInOut),
    );

    _tapScaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tapScaleController, curve: Curves.easeIn),
    );

    _screenPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _screenPulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _screenPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _edgeGlowController.dispose();
    _tapScaleController.dispose();
    _screenPulseController.dispose();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  void _updateScreenPulse() {
    if (_combo >= 4) {
      if (!_screenPulseController.isAnimating) {
        _screenPulseController.repeat(reverse: true);
      }
    } else {
      _screenPulseController.stop();
      _screenPulseController.value = 1.0;
    }
  }

  void _startCountdown() {
    setState(() => _phase = _StreakPhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _StreakPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;
    _audio.startHeartbeat(speed: 0.5);

    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _StreakPhase.timing) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      });

      final ratio = (_elapsedSeconds / _targetTime).clamp(0.0, 2.0);
      _audio.setHeartbeatSpeed(0.5 + ratio * 1.5);
      _edgeGlowController.value = ratio.clamp(0.0, 1.0);

      if (_elapsedSeconds >= _targetTime - 0.5 && _elapsedSeconds < _targetTime) {
        _audio.stopHeartbeat();
      }
    });
  }

  void _onTap() {
    if (_phase != _StreakPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;
    final absDiff = (roundedActual - _targetTime).abs();

    if (absDiff <= 0.150) {
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
    } else {
      _combo = 0;
    }

    final baseScore = (1000 - (absDiff * 1000)).clamp(0, 1000).round();
    _totalScore += (baseScore * _comboMultiplier).round();

    _tapScaleController.forward().then((_) => _tapScaleController.reverse());
    _updateScreenPulse();

    setState(() => _phase = _StreakPhase.done);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_currentRound >= _totalRounds) {
        _showResults(absDiff, roundedActual);
      } else {
        setState(() {
          _currentRound++;
          _targetTime = PrecisionCalculator.generateTarget();
          _phase = _StreakPhase.showTarget;
        });
      }
    });
  }

  Future<void> _showResults(double lastDiff, double lastActual) async {
    final storage = await StorageService.getInstance();
    final previousHigh = storage.streakMultiplierHighScore;
    final isNewHigh = _totalScore > previousHigh;
    if (isNewHigh) {
      await storage.saveStreakMultiplierHighScore(_totalScore);
    }
    await storage.addGameResult(lastDiff);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppTheme.fadeRoute(
        _StreakResultsScreen(
          totalScore: _totalScore,
          bestCombo: _bestCombo,
          highScore: isNewHigh ? _totalScore : previousHigh,
          isNewHigh: isNewHigh,
          lastResult: GameResult(
            targetTime: _targetTime,
            actualTime: lastActual,
            playerName: storage.name,
          ),
          onPlayAgain: () {
            Navigator.of(context).pushReplacement(
              AppTheme.fadeRoute(const StreakMultiplierScreen()),
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
      body: AnimatedBuilder(
        animation: _screenPulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _combo >= 4 ? _screenPulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: SafeArea(
          child: Stack(
            children: [
              if (_vignetteOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [
                            Colors.transparent,
                            _neonCyan.withValues(alpha: _vignetteOpacity),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (_phase == _StreakPhase.timing)
                AnimatedBuilder(
                  animation: _edgeGlowAnimation,
                  builder: (context, _) {
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.purple.withValues(
                                alpha: _edgeGlowAnimation.value * 0.3,
                              ),
                              width: _edgeGlowAnimation.value * 4,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          'ROUND $_currentRound/$_totalRounds',
                          style: AppTheme.labelStyle.copyWith(
                            color: _neonCyan,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 36),
                      ],
                    ),
                  ),
                  ComboMeter(combo: _combo),
                  const Spacer(),

                  if (_phase == _StreakPhase.showTarget) ...[
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        decoration: AppTheme.neonGlow(color: _neonCyan),
                        child: Text(
                          'READY',
                          style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                        ),
                      ),
                    ),
                  ],

                  if (_phase == _StreakPhase.countdown)
                    CountdownWidget(onComplete: _startTiming),

                  if (_phase == _StreakPhase.timing) ...[
                    ArcTimer(
                      elapsed: _elapsedSeconds,
                      target: _targetTime,
                      isRunning: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TARGET ${PrecisionCalculator.formatTime(_targetTime)}s',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.dimWhite.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                                  color: _neonCyan.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonCyan.withValues(
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
                                    color: _neonCyan,
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

                  if (_phase == _StreakPhase.done)
                    Text(
                      'SCORE: $_totalScore',
                      style: AppTheme.headingMedium.copyWith(color: _neonCyan),
                    ),

                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakResultsScreen extends StatelessWidget {
  final int totalScore;
  final int bestCombo;
  final int highScore;
  final bool isNewHigh;
  final GameResult lastResult;
  final VoidCallback onPlayAgain;

  const _StreakResultsScreen({
    required this.totalScore,
    required this.bestCombo,
    required this.highScore,
    required this.isNewHigh,
    required this.lastResult,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SESSION COMPLETE',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 24),
              Text(
                '$totalScore',
                style: AppTheme.timerDisplay.copyWith(
                  color: const Color(0xFF00FFFF),
                  fontSize: 64,
                ),
              ),
              Text(
                'TOTAL SCORE',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statBox('BEST COMBO', '×$bestCombo', AppTheme.amber),
                  const SizedBox(width: 16),
                  _statBox(
                    'HIGH SCORE',
                    '$highScore',
                    isNewHigh ? AppTheme.amber : AppTheme.dimWhite,
                    showCrown: isNewHigh,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Last: ${lastResult.tier.displayName} (±${lastResult.absDifference.toStringAsFixed(2)}s)',
                style: AppTheme.bodyMedium.copyWith(
                  color: lastResult.tier.color,
                ),
              ),
              const Spacer(),
              GlowButton(
                text: 'PLAY AGAIN',
                onTap: onPlayAgain,
                color: const Color(0xFF00FFFF),
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

  Widget _statBox(String label, String value, Color color, {bool showCrown = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: AppTheme.neonBorder(color: color, borderRadius: 12),
      child: Column(
        children: [
          if (showCrown)
            const Icon(Icons.emoji_events, color: AppTheme.amber, size: 20),
          Text(label, style: AppTheme.labelStyle),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
