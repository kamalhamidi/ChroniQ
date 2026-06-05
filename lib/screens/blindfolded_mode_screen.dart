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
import 'reveal_screen.dart';

enum _BlindPhase { showTarget, countdown, timing, done }

class BlindfoldedModeScreen extends StatefulWidget {
  const BlindfoldedModeScreen({super.key});

  @override
  State<BlindfoldedModeScreen> createState() => _BlindfoldedModeScreenState();
}

class _BlindfoldedModeScreenState extends State<BlindfoldedModeScreen>
    with TickerProviderStateMixin {
  static const Color _neonRed = Color(0xFFFF3B3B);

  _BlindPhase _phase = _BlindPhase.showTarget;
  late double _targetTime;
  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _edgeGlowController;
  late Animation<double> _edgeGlowAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;
  late AnimationController _hideDigitsController;
  late Animation<double> _hideDigitsAnimation;
  late AnimationController _placeholderPulseController;
  late Animation<double> _placeholderPulseAnimation;

  Timer? _heartbeatCheckTimer;
  double _elapsedSeconds = 0;
  bool _digitsHidden = false;

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

    _hideDigitsController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _hideDigitsAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _hideDigitsController, curve: Curves.easeOut),
    );

    _placeholderPulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _placeholderPulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _placeholderPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _edgeGlowController.dispose();
    _tapScaleController.dispose();
    _hideDigitsController.dispose();
    _placeholderPulseController.dispose();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _phase = _BlindPhase.countdown);
  }

  void _startTiming() {
    setState(() {
      _phase = _BlindPhase.timing;
      _digitsHidden = false;
    });
    _hideDigitsController.reset();
    _placeholderPulseController.stop();
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;
    _audio.startHeartbeat(speed: 0.5);

    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _BlindPhase.timing) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      });

      if (!_digitsHidden && _elapsedSeconds >= 2.0) {
        _digitsHidden = true;
        _hideDigitsController.forward();
        _placeholderPulseController.repeat(reverse: true);
      }

      final ratio = (_elapsedSeconds / _targetTime).clamp(0.0, 2.0);
      _audio.setHeartbeatSpeed(0.5 + ratio * 1.5);
      _edgeGlowController.value = ratio.clamp(0.0, 1.0);

      if (_elapsedSeconds >= _targetTime - 0.5 && _elapsedSeconds < _targetTime) {
        _audio.stopHeartbeat();
      }
    });
  }

  void _onTap() {
    if (_phase != _BlindPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;

    setState(() => _phase = _BlindPhase.done);

    _tapScaleController.forward().then((_) => _tapScaleController.reverse());

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final storage = await StorageService.getInstance();
      final result = GameResult(
        targetTime: _targetTime,
        actualTime: roundedActual,
        playerName: storage.name,
      );

      if (result.absDifference < storage.blindBestPrecision) {
        await storage.saveBlindBestPrecision(result.absDifference);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppTheme.fadeRoute(
          RevealScreen(
            result: result,
            onPlayAgain: () {
              Navigator.of(context).pushReplacement(
                AppTheme.fadeRoute(const BlindfoldedModeScreen()),
              );
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Stack(
          children: [
            if (_digitsHidden)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_phase == _BlindPhase.timing)
              AnimatedBuilder(
                animation: _edgeGlowAnimation,
                builder: (context, _) {
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _neonRed.withValues(
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

            if (_digitsHidden)
              Positioned(
                top: 16,
                right: 16,
                child: Text(
                  'BLINDFOLDED',
                  style: AppTheme.labelStyle.copyWith(
                    color: _neonRed,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            Column(
              children: [
                Align(
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
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.dimWhite,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                if (_phase == _BlindPhase.showTarget) ...[
                  Text(
                    'TARGET TIME',
                    style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${PrecisionCalculator.formatTime(_targetTime)}s',
                    style: AppTheme.timerDisplay.copyWith(fontSize: 56),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Digits hide after 2 seconds',
                    style: AppTheme.bodySmall.copyWith(color: _neonRed),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _startCountdown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: AppTheme.neonGlow(color: _neonRed),
                      child: Text(
                        'READY',
                        style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                      ),
                    ),
                  ),
                ],

                if (_phase == _BlindPhase.countdown)
                  CountdownWidget(onComplete: _startTiming),

                if (_phase == _BlindPhase.timing) ...[
                  if (!_digitsHidden)
                    AnimatedBuilder(
                      animation: _hideDigitsAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _hideDigitsAnimation.value,
                          child: child,
                        );
                      },
                      child: ArcTimer(
                        elapsed: _elapsedSeconds,
                        target: _targetTime,
                        isRunning: true,
                      ),
                    )
                  else
                    Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF111118),
                      ),
                      child: AnimatedBuilder(
                        animation: _placeholderPulseAnimation,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _placeholderPulseAnimation.value,
                            child: Center(
                              child: Text(
                                '??:??',
                                style: AppTheme.timerDisplay.copyWith(
                                  fontSize: 48,
                                  color: _neonRed,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (!_digitsHidden)
                    Text(
                      'TARGET ${PrecisionCalculator.formatTime(_targetTime)}s',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.dimWhite.withValues(alpha: 0.4),
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
                                color: _neonRed.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _neonRed.withValues(
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
                                  color: _neonRed,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _digitsHidden ? 'PURE INSTINCT' : 'FEEL THE MOMENT',
                    style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.dimWhite.withValues(alpha: 0.3),
                      letterSpacing: 4,
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
