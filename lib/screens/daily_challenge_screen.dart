import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/bot_service.dart';
import '../services/storage_service.dart';
import '../models/game_result.dart';
import '../utils/daily_seed.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/glow_button.dart';
import '../widgets/precision_tier_card.dart';
import '../widgets/timeline_replay.dart';

enum _DailyPhase { intro, countdown, timing, reveal, leaderboard }

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen>
    with TickerProviderStateMixin {
  _DailyPhase _phase = _DailyPhase.intro;

  late double _targetTime;
  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();
  final BotService _botService = BotService.getInstance();

  GameResult? _result;
  List<Map<String, dynamic>> _leaderboard = [];
  // ignore: unused_field
  bool _alreadyPlayed = false;
  String _countdown = '';
  Timer? _countdownTimer;
  int _userPosition = 0;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _targetTime = DailySeed.getDailyTarget(DateTime.now());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkAlreadyPlayed();
  }

  Future<void> _checkAlreadyPlayed() async {
    final storage = await StorageService.getInstance();
    if (storage.isDailyPlayed()) {
      setState(() {
        _alreadyPlayed = true;
        _phase = _DailyPhase.leaderboard;
      });
      _startCountdownTimer();
      // Generate leaderboard with previous result
      final prevResult = storage.lastDailyResult ?? 0.5;
      _generateLeaderboard(prevResult);
    }
  }

  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (!mounted) return;
    setState(() {
      _countdown = DailySeed.formatCountdown(DailySeed.getTimeUntilReset());
    });
  }

  void _startGame() {
    setState(() => _phase = _DailyPhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _DailyPhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _audio.startHeartbeat(speed: 0.6);
  }

  void _onTap() {
    if (_phase != _DailyPhase.timing) return;

    _stopwatch.stop();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;

    _result = GameResult(
      targetTime: _targetTime,
      actualTime: roundedActual,
      playerName: 'YOU',
    );

    _saveAndReveal();
  }

  Future<void> _saveAndReveal() async {
    final storage = await StorageService.getInstance();
    await storage.addGameResult(_result!.absDifference);
    await storage.saveDailyResult(_result!.absDifference);

    if (_result!.tier == PrecisionTier.bad) {
      _audio.playBadResult();
    } else {
      _audio.playGoodResult();
    }

    _generateLeaderboard(_result!.absDifference);

    if (!mounted) return;
    setState(() => _phase = _DailyPhase.reveal);

    // Scroll to user position after a delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() => _phase = _DailyPhase.leaderboard);
      _startCountdownTimer();
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollToUser();
      });
    });
  }

  void _generateLeaderboard(double userResult) {
    _leaderboard = _botService.generateFakeLeaderboard(userResult, 50);
    _userPosition = _leaderboard.indexWhere((e) => e['isUser'] == true) + 1;
  }

  void _scrollToUser() {
    final userIdx = _leaderboard.indexWhere((e) => e['isUser'] == true);
    if (userIdx >= 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        userIdx * 56.0, // approximate item height
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _scrollController.dispose();
    _audio.stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _DailyPhase.intro:
        return _buildIntro();
      case _DailyPhase.countdown:
        return Center(child: CountdownWidget(onComplete: _startTiming));
      case _DailyPhase.timing:
        return _buildTiming();
      case _DailyPhase.reveal:
        return _buildReveal();
      case _DailyPhase.leaderboard:
        return _buildLeaderboard();
    }
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardBg,
                  border: Border.all(color: AppTheme.dimWhite.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.dimWhite, size: 20),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'DAILY CHALLENGE',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.amber,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.red.withValues(alpha: 0.4)),
            ),
            child: Text(
              'ONE SHOT. NO RETRY.',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.red,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'TARGET',
            style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 8),
          Text(
            '${PrecisionCalculator.formatTime(_targetTime)}s',
            style: AppTheme.timerDisplay.copyWith(
              color: AppTheme.amber,
              shadows: [
                Shadow(
                  color: AppTheme.amber.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          GlowButton(
            text: 'BEGIN',
            onTap: _startGame,
            color: AppTheme.amber,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTiming() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${PrecisionCalculator.formatTime(_targetTime)}s',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.dimWhite.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _onTap,
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
                      color: AppTheme.amber.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.amber.withValues(alpha: _pulseAnimation.value),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'TAP',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.amber,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ONE SHOT',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.red.withValues(alpha: 0.5),
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReveal() {
    if (_result == null) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YOUR TIME',
            style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 12),
          Text(
            '${_result!.actualTime.toStringAsFixed(2)}s',
            style: AppTheme.timerDisplay.copyWith(
              color: _result!.tier.color,
              shadows: [
                Shadow(
                  color: _result!.tier.color.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrecisionTierCard(tier: _result!.tier),
          const SizedBox(height: 16),
          Text(
            _result!.differenceText,
            style: AppTheme.headingSmall.copyWith(
              color: _result!.isEarly ? AppTheme.cyan : AppTheme.red,
            ),
          ),
          const SizedBox(height: 20),
          TimelineReplay(
            targetTime: _result!.targetTime,
            actualTime: _result!.actualTime,
            tier: _result!.tier,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading global rankings...',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.dimWhite.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.amber.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardBg,
                  border: Border.all(color: AppTheme.dimWhite.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.dimWhite, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'DAILY RANKING',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.amber,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your position: #$_userPosition',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.amber),
          ),
          const SizedBox(height: 4),
          Text(
            'Next challenge in: $_countdown',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.dimWhite.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),

          // Leaderboard
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _leaderboard.length,
              itemBuilder: (context, i) {
                final entry = _leaderboard[i];
                final isUser = entry['isUser'] as bool;
                return Container(
                  height: 52,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.amber.withValues(alpha: 0.1)
                        : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: isUser
                        ? Border.all(color: AppTheme.amber, width: 1.5)
                        : null,
                    boxShadow: isUser
                        ? [BoxShadow(color: AppTheme.amber.withValues(alpha: 0.3), blurRadius: 10)]
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: i < 3 ? AppTheme.amber : AppTheme.dimWhite,
                            fontWeight: i < 3 ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(entry['flag'] as String, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry['username'] as String,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isUser ? AppTheme.amber : AppTheme.white,
                            fontWeight: isUser ? FontWeight.w700 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '±${(entry['result'] as double).toStringAsFixed(3)}s',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.dimWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GlowButton(
            text: 'HOME',
            onTap: () => Navigator.of(context).pop(),
            color: AppTheme.amber,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
