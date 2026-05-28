import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/bot_service.dart';
import '../services/storage_service.dart';
import '../models/bot_player.dart';
import '../models/game_result.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/fake_player_card.dart';
import '../widgets/glow_button.dart';

enum _OnlinePhase { searching, lobby, countdown, timing, waiting, results }

class OnlineModeScreen extends StatefulWidget {
  const OnlineModeScreen({super.key});

  @override
  State<OnlineModeScreen> createState() => _OnlineModeScreenState();
}

class _OnlineModeScreenState extends State<OnlineModeScreen>
    with TickerProviderStateMixin {
  final BotService _botService = BotService.getInstance();
  final AudioService _audio = AudioService.getInstance();
  final Random _rng = Random();

  // Phases
  _OnlinePhase _phase = _OnlinePhase.searching;

  // Matchmaking
  int _fakePing = 42;
  double _searchProgress = 0.0;
  Timer? _searchTimer;
  Timer? _pingTimer;

  // Lobby
  List<BotPlayer> _bots = [];
  List<MapEntry<String, String>> _chatMessages = [];
  int _matchCountdown = 3;

  // Game
  late double _targetTime;
  final Stopwatch _stopwatch = Stopwatch();
  GameResult? _userResult;
  final List<GameResult> _allResults = [];
  final Map<String, String> _botReactions = {};
  final int _roundNumber = 1;

  // Player info
  String _userName = '';
  String _userFlag = '';

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;

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

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _dotsAnimation = IntTween(begin: 0, end: 3).animate(_dotsController);

    _loadUserAndStart();
  }

  Future<void> _loadUserAndStart() async {
    final storage = await StorageService.getInstance();
    _userName = storage.username;
    _userFlag = storage.flag;
    _startMatchmaking();
  }

  void _startMatchmaking() {
    _fakePing = _botService.generateFakePing();
    final searchDuration = 3000 + _rng.nextInt(2000); // 3-5 seconds

    // Animate search progress
    _searchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _searchProgress += 50.0 / searchDuration;
        if (_searchProgress >= 1.0) {
          timer.cancel();
          _enterLobby();
        }
      });
    });

    // Fake ping changes
    _pingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _fakePing = _botService.generateFakePing());
    });
  }

  void _enterLobby() {
    _pingTimer?.cancel();
    _bots = _botService.getRandomBots(3);
    _chatMessages = _botService.getRandomChatMessages(_bots, count: 2);
    _targetTime = PrecisionCalculator.generateTarget();

    setState(() => _phase = _OnlinePhase.lobby);

    // Start match countdown after bots are "ready"
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (!mounted) return;
      _startMatchCountdown();
    });
  }

  void _startMatchCountdown() {
    setState(() {
      _phase = _OnlinePhase.countdown;
      _matchCountdown = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _matchCountdown--;
        if (_matchCountdown <= 0) {
          timer.cancel();
          _phase = _OnlinePhase.countdown; // Will show the 3-2-1-GO countdown
        }
      });
    });
  }

  void _startTiming() {
    setState(() => _phase = _OnlinePhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _audio.startHeartbeat(speed: 0.8);
  }

  void _onTap() {
    if (_phase != _OnlinePhase.timing) return;

    _stopwatch.stop();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;

    _userResult = GameResult(
      targetTime: _targetTime,
      actualTime: roundedActual,
      playerName: _userName,
    );

    setState(() => _phase = _OnlinePhase.waiting);
    _waitForBotResults();
  }

  Future<void> _waitForBotResults() async {
    _allResults.clear();
    _allResults.add(_userResult!);

    // Simulate bot results arriving with delays
    for (final bot in _bots) {
      if (bot.hasRageQuit) continue;

      final botResult = await _botService.simulateBotResult(
        bot,
        _targetTime,
        _roundNumber,
      );

      if (!mounted) return;

      if (bot.hasRageQuit) {
        // Show rage quit snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.red.withValues(alpha: 0.9),
              content: Text(
                '${bot.username} left the match',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _allResults.add(botResult);
      }
    }

    // Generate reactions
    for (final bot in _bots) {
      if (bot.hasRageQuit) continue;
      final botResult = _allResults.firstWhere(
        (r) => r.playerName == bot.username,
        orElse: () => _userResult!,
      );
      _botReactions[bot.username] = _botService.getBotReaction(bot, botResult, _userResult!);
    }

    if (!mounted) return;
    setState(() => _phase = _OnlinePhase.results);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    _searchTimer?.cancel();
    _pingTimer?.cancel();
    _audio.stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _OnlinePhase.searching:
        return _buildSearching();
      case _OnlinePhase.lobby:
        return _buildLobby();
      case _OnlinePhase.countdown:
        return Center(child: CountdownWidget(onComplete: _startTiming));
      case _OnlinePhase.timing:
        return _buildTiming();
      case _OnlinePhase.waiting:
        return _buildWaiting();
      case _OnlinePhase.results:
        return _buildResults();
    }
  }

  Widget _buildSearching() {
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
          // Animated searching dots
          AnimatedBuilder(
            animation: _dotsAnimation,
            builder: (context, _) {
              final dots = '.' * (_dotsAnimation.value + 1);
              return Text(
                'Searching for players$dots',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.green,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Fake ping
          Text(
            'Ping: ${_fakePing}ms',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.dimWhite.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _searchProgress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.green.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Neon spinner
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.green.withValues(alpha: 0.6)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text('MATCH FOUND', style: AppTheme.headingMedium.copyWith(
            color: AppTheme.green, letterSpacing: 3)),
          const SizedBox(height: 24),

          // Player cards
          FakePlayerCard(
            username: _userName,
            flagEmoji: _userFlag,
            isUser: true,
            showReady: true,
            readyDelay: 0,
          ),
          ...List.generate(_bots.length, (i) {
            return FakePlayerCard(
              username: _bots[i].username,
              flagEmoji: _bots[i].flagEmoji,
              showReady: true,
              readyDelay: 800 + i * 700,
              isOnline: _bots[i].isOnline,
            );
          }),

          const SizedBox(height: 20),

          // Chat messages
          if (_chatMessages.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _chatMessages.map((msg) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${msg.key}: ',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: msg.value,
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const Spacer(),
          Text(
            'MATCH STARTING...',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.green,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 30),
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
            'TARGET: ${PrecisionCalculator.formatTime(_targetTime)}s',
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
                      color: AppTheme.green.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.green.withValues(alpha: _pulseAnimation.value),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'TAP',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.green,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _dotsAnimation,
            builder: (context, _) {
              final dots = '.' * (_dotsAnimation.value + 1);
              return Text(
                'Opponents are timing$dots',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.dimWhite,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.green.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // Sort by precision
    final sorted = List<GameResult>.from(_allResults);
    sorted.sort((a, b) => a.absDifference.compareTo(b.absDifference));
    final userWon = sorted.first.playerName == _userName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            userWon ? '🏆 VICTORY!' : '💀 DEFEAT',
            style: AppTheme.headingLarge.copyWith(
              color: userWon ? AppTheme.purple : AppTheme.red,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),

          // Results leaderboard
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final result = sorted[i];
                final isUser = result.playerName == _userName;
                final isWinner = i == 0;

                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: Duration(milliseconds: 300 + i * 300),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWinner
                            ? AppTheme.purple
                            : isUser
                                ? AppTheme.cyan.withValues(alpha: 0.4)
                                : AppTheme.dimWhite.withValues(alpha: 0.1),
                        width: isWinner ? 2 : 1,
                      ),
                      boxShadow: isWinner
                          ? [BoxShadow(color: AppTheme.purple.withValues(alpha: 0.4), blurRadius: 16)]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          isWinner ? '👑' : '${i + 1}',
                          style: TextStyle(
                            fontSize: isWinner ? 22 : 18,
                            color: AppTheme.dimWhite,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? '$_userName (YOU)' : result.playerName,
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isUser ? AppTheme.cyan : AppTheme.white,
                                ),
                              ),
                              if (_botReactions.containsKey(result.playerName))
                                Text(
                                  _botReactions[result.playerName]!,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.dimWhite.withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '±${result.absDifference.toStringAsFixed(3)}s',
                              style: AppTheme.bodyLarge.copyWith(
                                color: result.tier.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              result.tier.displayName,
                              style: AppTheme.bodySmall.copyWith(
                                color: result.tier.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          GlowButton(
            text: 'PLAY AGAIN',
            onTap: () {
              Navigator.of(context).pushReplacement(
                AppTheme.fadeRoute(const OnlineModeScreen()),
              );
            },
            color: AppTheme.green,
          ),
          const SizedBox(height: 10),
          GlowButton(
            text: 'HOME',
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            color: AppTheme.cyan,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
