import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/game_result.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/precision_tier_card.dart';
import '../widgets/timeline_replay.dart';
import '../widgets/glow_button.dart';

class RevealScreen extends StatefulWidget {
  final GameResult result;
  final VoidCallback? onPlayAgain;
  final bool isBattle;
  final List<GameResult>? allResults; // For battle/online mode

  const RevealScreen({
    super.key,
    required this.result,
    this.onPlayAgain,
    this.isBattle = false,
    this.allResults,
  });

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen>
    with TickerProviderStateMixin {
  bool _showContent = false;
  bool _showTier = false;
  bool _showDifference = false;
  bool _showTimeline = false;
  bool _showButtons = false;
  bool _showLeaderboard = false;

  double _displayedTime = 0.00;
  Timer? _rollTimer;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-8, 0)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: const Offset(-8, 0), end: const Offset(8, 0)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: const Offset(8, 0), end: const Offset(-6, 0)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: const Offset(-6, 0), end: const Offset(6, 0)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: const Offset(6, 0), end: const Offset(-3, 0)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: const Offset(-3, 0), end: Offset.zero), weight: 15),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    _startRevealSequence();
  }

  Future<void> _startRevealSequence() async {
    // Save result
    final storage = await StorageService.getInstance();
    await storage.addGameResult(widget.result.absDifference);

    // 500ms black freeze
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Start number roll
    setState(() => _showContent = true);
    _startNumberRoll();

    // After roll, show tier
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _showTier = true);

    // Play sound based on result
    final audio = AudioService.getInstance();
    if (widget.result.tier == PrecisionTier.bad) {
      audio.playBadResult();
      _shakeController.forward();
      HapticFeedback.heavyImpact();
    } else {
      audio.playGoodResult();
      if (widget.result.tier == PrecisionTier.godlike ||
          widget.result.tier == PrecisionTier.perfect) {
        _flashController.forward().then((_) => _flashController.reverse());
      }
    }

    // Show difference
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showDifference = true);

    // Show timeline
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showTimeline = true);

    // Show leaderboard for battle/online
    if (widget.isBattle && widget.allResults != null) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _showLeaderboard = true);
    }

    // Show buttons
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _showButtons = true);
  }

  void _startNumberRoll() {
    final target = widget.result.actualTime;
    const rollDuration = 600; // ms
    const steps = 20;
    int step = 0;
    final rng = Random();

    _rollTimer = Timer.periodic(
      const Duration(milliseconds: rollDuration ~/ 20),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        step++;
        if (step >= steps) {
          timer.cancel();
          setState(() => _displayedTime = target);
          return;
        }
        // Random numbers converging to target
        final progress = step / steps;
        final noise = (1 - progress) * (rng.nextDouble() * 5);
        setState(() {
          _displayedTime = target * progress + noise * (1 - progress);
        });
      },
    );
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          // Flash overlay
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, _) {
              if (_flashAnimation.value == 0) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: AppTheme.purple.withValues(alpha: _flashAnimation.value),
                  ),
                ),
              );
            },
          ),

          // Main content with shake
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: _shakeAnimation.value,
                child: child,
              );
            },
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Time display
                      if (_showContent) ...[
                        Text(
                          'YOUR TIME',
                          style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_displayedTime.toStringAsFixed(2)}s',
                          style: AppTheme.timerDisplay.copyWith(
                            color: widget.result.tier.color,
                            shadows: [
                              Shadow(
                                color: widget.result.tier.color.withValues(alpha: 0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TARGET: ${widget.result.targetTime.toStringAsFixed(2)}s',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.dimWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Tier card
                      if (_showTier)
                        PrecisionTierCard(tier: widget.result.tier),

                      const SizedBox(height: 20),

                      // Difference text
                      if (_showDifference)
                        AnimatedOpacity(
                          opacity: _showDifference ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            widget.result.differenceText,
                            style: AppTheme.headingSmall.copyWith(
                              color: widget.result.isPerfect
                                  ? AppTheme.purple
                                  : widget.result.isEarly
                                      ? AppTheme.cyan
                                      : AppTheme.red,
                              letterSpacing: 2,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Timeline replay
                      if (_showTimeline)
                        AnimatedOpacity(
                          opacity: _showTimeline ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: TimelineReplay(
                            targetTime: widget.result.targetTime,
                            actualTime: widget.result.actualTime,
                            tier: widget.result.tier,
                          ),
                        ),

                      // Battle leaderboard
                      if (_showLeaderboard && widget.allResults != null) ...[
                        const SizedBox(height: 20),
                        _buildLeaderboard(),
                      ],

                      const Spacer(),

                      // Buttons
                      if (_showButtons) ...[
                        if (widget.onPlayAgain != null)
                          GlowButton(
                            text: 'PLAY AGAIN',
                            onTap: widget.onPlayAgain!,
                            color: AppTheme.purple,
                          ),
                        const SizedBox(height: 12),
                        GlowButton(
                          text: 'HOME',
                          onTap: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          color: AppTheme.cyan,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (widget.allResults == null) return const SizedBox.shrink();
    
    final sorted = List<GameResult>.from(widget.allResults!);
    sorted.sort((a, b) => a.absDifference.compareTo(b.absDifference));

    return Column(
      children: [
        Text(
          'LEADERBOARD',
          style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map((entry) {
          final idx = entry.key;
          final result = entry.value;
          final isWinner = idx == 0;
          final isUser = result.playerName == widget.result.playerName;

          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + idx * 200),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWinner
                      ? AppTheme.purple
                      : isUser
                          ? AppTheme.cyan.withValues(alpha: 0.4)
                          : AppTheme.dimWhite.withValues(alpha: 0.1),
                  width: isWinner ? 2 : 1,
                ),
                boxShadow: isWinner
                    ? [
                        BoxShadow(
                          color: AppTheme.purple.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    isWinner ? '👑' : '${idx + 1}.',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.playerName,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: isUser ? FontWeight.w700 : FontWeight.w400,
                        color: isUser ? AppTheme.cyan : AppTheme.white,
                      ),
                    ),
                  ),
                  Text(
                    '±${result.absDifference.toStringAsFixed(3)}s',
                    style: AppTheme.bodyMedium.copyWith(
                      color: result.tier.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
