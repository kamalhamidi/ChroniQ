import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/game_result.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import 'reveal_screen.dart';

enum _PrecisionPhase { showTarget, countdown, timing, done }

class PrecisionModeScreen extends StatefulWidget {
  const PrecisionModeScreen({super.key});

  @override
  State<PrecisionModeScreen> createState() => _PrecisionModeScreenState();
}

class _PrecisionModeScreenState extends State<PrecisionModeScreen>
    with TickerProviderStateMixin {
  _PrecisionPhase _phase = _PrecisionPhase.showTarget;
  late double _targetTime;
  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _edgeGlowController;
  late Animation<double> _edgeGlowAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;

  Timer? _heartbeatCheckTimer;
  double _elapsedSeconds = 0;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _edgeGlowController.dispose();
    _tapScaleController.dispose();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _phase = _PrecisionPhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _PrecisionPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _audio.startHeartbeat(speed: 0.5);

    // Monitor elapsed time for psychological pressure
    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _PrecisionPhase.timing) {
        timer.cancel();
        return;
      }
      _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;

      // Increase heartbeat speed as approaching target
      final ratio = (_elapsedSeconds / _targetTime).clamp(0.0, 2.0);
      _audio.setHeartbeatSpeed(0.5 + ratio * 1.5);

      // Edge glow intensifies
      _edgeGlowController.value = (ratio).clamp(0.0, 1.0);

      // Silence zone: 500ms before target
      if (_elapsedSeconds >= _targetTime - 0.5 && _elapsedSeconds < _targetTime) {
        _audio.stopHeartbeat();
      }
    });
  }

  void _onTap() {
    if (_phase != _PrecisionPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;

    setState(() => _phase = _PrecisionPhase.done);

    _tapScaleController.forward().then((_) {
      _tapScaleController.reverse();
    });

    // Navigate to reveal
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final storage = await StorageService.getInstance();
      final result = GameResult(
        targetTime: _targetTime,
        actualTime: roundedActual,
        playerName: storage.name,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppTheme.fadeRoute(RevealScreen(
          result: result,
          onPlayAgain: () {
            Navigator.of(context).pushReplacement(
              AppTheme.fadeRoute(const PrecisionModeScreen()),
            );
          },
        )),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Edge glow effect
            if (_phase == _PrecisionPhase.timing)
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
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withValues(
                                alpha: _edgeGlowAnimation.value * 0.2,
                              ),
                              blurRadius: _edgeGlowAnimation.value * 30,
                              spreadRadius: _edgeGlowAnimation.value * 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Main content
            Column(
              children: [
                // Back button
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

                // Phase content
                if (_phase == _PrecisionPhase.showTarget) ...[
                  Text(
                    'TARGET TIME',
                    style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.white.withValues(alpha: 0.1),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Text(
                      '${PrecisionCalculator.formatTime(_targetTime)}s',
                      style: AppTheme.timerDisplay,
                    ),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _startCountdown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: AppTheme.neonGlow(color: AppTheme.purple),
                      child: Text(
                        'READY',
                        style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                      ),
                    ),
                  ),
                ],

                if (_phase == _PrecisionPhase.countdown)
                  CountdownWidget(onComplete: _startTiming),

                if (_phase == _PrecisionPhase.timing) ...[
                  Text(
                    '${PrecisionCalculator.formatTime(_targetTime)}s',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.dimWhite.withValues(alpha: 0.4),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Tap button
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
                                color: AppTheme.purple.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.purple.withValues(
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
                                  color: AppTheme.purple,
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
                    'FEEL THE MOMENT',
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
