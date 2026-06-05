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
import '../widgets/zone_hint_bar.dart';
import '../widgets/glow_button.dart';

enum _ZonesPhase { showTarget, countdown, timing, reveal }
enum ZoneDifficulty { beginner, intermediate, pro }

class TargetZonesScreen extends StatefulWidget {
  const TargetZonesScreen({super.key});

  @override
  State<TargetZonesScreen> createState() => _TargetZonesScreenState();
}

class _TargetZonesScreenState extends State<TargetZonesScreen>
    with TickerProviderStateMixin {
  static const Color _neonGreen = Color(0xFF00FF88);

  _ZonesPhase _phase = _ZonesPhase.showTarget;
  ZoneDifficulty _difficulty = ZoneDifficulty.beginner;
  late double _targetTime;
  late double _zoneLower;
  late double _zoneUpper;
  bool _zoneCollapsed = false;
  bool _zoneRevealed = false;
  bool _showTooltip = false;

  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _edgeGlowController;
  late Animation<double> _edgeGlowAnimation;
  late AnimationController _tapScaleController;
  late Animation<double> _tapScaleAnimation;

  Timer? _heartbeatCheckTimer;
  double _elapsedSeconds = 0;
  double? _actualTime;
  bool? _hintAccurate;

  double get _zoneHalfWidth {
    switch (_difficulty) {
      case ZoneDifficulty.beginner:
        return 1.5;
      case ZoneDifficulty.intermediate:
        return 0.8;
      case ZoneDifficulty.pro:
        return 0.3;
    }
  }

  @override
  void initState() {
    super.initState();
    _generateTarget();

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

    _checkTooltip();
  }

  Future<void> _checkTooltip() async {
    final storage = await StorageService.getInstance();
    if (!storage.zonesTooltipSeen && mounted) {
      setState(() => _showTooltip = true);
    }
  }

  void _dismissTooltip() async {
    final storage = await StorageService.getInstance();
    await storage.setZonesTooltipSeen();
    if (mounted) setState(() => _showTooltip = false);
  }

  void _generateTarget() {
    _targetTime = PrecisionCalculator.generateTarget();
    _zoneLower = (_targetTime - _zoneHalfWidth).clamp(0.0, 10.0);
    _zoneUpper = (_targetTime + _zoneHalfWidth).clamp(0.0, 10.0);
    _zoneCollapsed = false;
    _zoneRevealed = false;
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
    setState(() => _phase = _ZonesPhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _ZonesPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSeconds = 0;
    _audio.startHeartbeat(speed: 0.5);

    _heartbeatCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _ZonesPhase.timing) {
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
    if (_phase != _ZonesPhase.timing) return;

    _stopwatch.stop();
    _heartbeatCheckTimer?.cancel();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actual = _stopwatch.elapsedMilliseconds / 1000.0;
    _actualTime = (actual * 100).round() / 100.0;
    _hintAccurate = _actualTime! >= _zoneLower && _actualTime! <= _zoneUpper;

    _tapScaleController.forward().then((_) => _tapScaleController.reverse());

    setState(() {
      _phase = _ZonesPhase.reveal;
      _zoneCollapsed = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _zoneRevealed = true);
    });

    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final storage = await StorageService.getInstance();
      final result = GameResult(
        targetTime: _targetTime,
        actualTime: _actualTime!,
        playerName: storage.name,
      );

      if (result.absDifference < storage.zonesBestPrecision) {
        await storage.saveZonesBestPrecision(result.absDifference);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppTheme.fadeRoute(
          _ZonesResultsScreen(
            result: result,
            hintAccurate: _hintAccurate!,
            zoneLower: _zoneLower,
            zoneUpper: _zoneUpper,
            onPlayAgain: () {
              Navigator.of(context).pushReplacement(
                AppTheme.fadeRoute(const TargetZonesScreen()),
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
            if (_phase == _ZonesPhase.timing)
              AnimatedBuilder(
                animation: _edgeGlowAnimation,
                builder: (context, _) {
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _neonGreen.withValues(
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

            if (_showTooltip)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _dismissTooltip,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.neonBorder(
                          color: const Color(0xFF00FFFF),
                          borderRadius: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.center_focus_strong,
                              color: Color(0xFF00FFFF),
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'HINT BAR',
                              style: AppTheme.headingSmall.copyWith(
                                color: const Color(0xFF00FFFF),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The cyan zone shows where the target time falls. '
                              'Narrow the range with difficulty to sharpen your instinct.',
                              style: AppTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'TAP TO DISMISS',
                              style: AppTheme.labelStyle.copyWith(
                                color: AppTheme.dimWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

                if (_phase == _ZonesPhase.showTarget) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildDifficultySelector(),
                  ),
                  const SizedBox(height: 24),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ZoneHintBar(
                    targetTime: _targetTime,
                    zoneLower: _zoneLower,
                    zoneUpper: _zoneUpper,
                    revealed: _zoneRevealed,
                    collapsed: _zoneCollapsed,
                  ),
                ),

                const Spacer(),

                if (_phase == _ZonesPhase.showTarget) ...[
                  Text(
                    'FIND YOUR RANGE',
                    style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _startCountdown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: AppTheme.neonGlow(color: _neonGreen),
                      child: Text(
                        'READY',
                        style: AppTheme.headingSmall.copyWith(letterSpacing: 3),
                      ),
                    ),
                  ),
                ],

                if (_phase == _ZonesPhase.countdown)
                  CountdownWidget(onComplete: _startTiming),

                if (_phase == _ZonesPhase.timing ||
                    _phase == _ZonesPhase.reveal) ...[
                  ArcTimer(
                    elapsed: _elapsedSeconds,
                    target: _targetTime,
                    isRunning: _phase == _ZonesPhase.timing,
                  ),
                  const SizedBox(height: 24),
                  if (_phase == _ZonesPhase.timing)
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
                                  color: _neonGreen.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _neonGreen.withValues(
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
                                    color: _neonGreen,
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

  Widget _buildDifficultySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _difficultyPill('BEGINNER', ZoneDifficulty.beginner),
        const SizedBox(width: 8),
        _difficultyPill('INTERMEDIATE', ZoneDifficulty.intermediate),
        const SizedBox(width: 8),
        _difficultyPill('PRO', ZoneDifficulty.pro),
      ],
    );
  }

  Widget _difficultyPill(String label, ZoneDifficulty diff) {
    final selected = _difficulty == diff;
    return GestureDetector(
      onTap: () {
        setState(() {
          _difficulty = diff;
          _generateTarget();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _neonGreen.withValues(alpha: 0.15) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _neonGreen : AppTheme.dimWhite.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: selected ? _neonGreen : AppTheme.dimWhite,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ZonesResultsScreen extends StatelessWidget {
  final GameResult result;
  final bool hintAccurate;
  final double zoneLower;
  final double zoneUpper;
  final VoidCallback onPlayAgain;

  const _ZonesResultsScreen({
    required this.result,
    required this.hintAccurate,
    required this.zoneLower,
    required this.zoneUpper,
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
                result.tier.emoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                result.tier.displayName,
                style: AppTheme.headingLarge.copyWith(
                  color: result.tier.color,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${result.actualTime.toStringAsFixed(2)}s',
                style: AppTheme.timerDisplay.copyWith(fontSize: 48),
              ),
              Text(
                'TARGET: ${result.targetTime.toStringAsFixed(2)}s',
                style: AppTheme.bodyMedium,
              ),
              Text(
                result.differenceText,
                style: AppTheme.bodyLarge.copyWith(color: result.tier.color),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.neonBorder(
                  color: hintAccurate
                      ? const Color(0xFF00FF88)
                      : const Color(0xFFFF3B3B),
                ),
                child: Column(
                  children: [
                    Text(
                      'HINT ACCURACY',
                      style: AppTheme.labelStyle.copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hintAccurate
                          ? 'Inside zone (${zoneLower.toStringAsFixed(1)}–${zoneUpper.toStringAsFixed(1)}s)'
                          : 'Outside zone (${zoneLower.toStringAsFixed(1)}–${zoneUpper.toStringAsFixed(1)}s)',
                      style: AppTheme.bodyMedium.copyWith(
                        color: hintAccurate
                            ? const Color(0xFF00FF88)
                            : const Color(0xFFFF3B3B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GlowButton(
                text: 'PLAY AGAIN',
                onTap: onPlayAgain,
                color: const Color(0xFF00FF88),
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
