import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../models/game_result.dart';
import '../utils/precision_calculator.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/glow_button.dart';
import 'reveal_screen.dart';

// ignore_for_file: unused_field
enum _BattlePhase { setup, focus, ready, countdown, timing, pass, results }

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key});

  @override
  State<BattleModeScreen> createState() => _BattleModeScreenState();
}

class _BattleModeScreenState extends State<BattleModeScreen>
    with TickerProviderStateMixin {
  // Setup
  int _playerCount = 2;
  final List<Map<String, String>> _players = [];
  final List<TextEditingController> _nameControllers = [];

  // Game state
  int _currentPlayerIdx = 0;
  final int _currentRound = 1;
  late double _targetTime;
  final List<GameResult> _roundResults = [];
  final List<GameResult> _allResults = [];

  // Phase
  _BattlePhase _phase = _BattlePhase.setup;

  // Timing
  final Stopwatch _stopwatch = Stopwatch();
  final AudioService _audio = AudioService.getInstance();

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _flags = ['🇺🇸', '🇬🇧', '🇫🇷', '🇩🇪', '🇯🇵', '🇧🇷', '🇰🇷', '🇮🇳', '🇨🇦', '🇦🇺'];

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
    _initPlayers();
  }

  void _initPlayers() {
    _nameControllers.clear();
    _players.clear();
    for (int i = 0; i < 4; i++) {
      _nameControllers.add(TextEditingController());
      _players.add({'name': '', 'flag': _flags[i]});
    }
    _loadFirstPlayer();
  }

  Future<void> _loadFirstPlayer() async {
    final storage = await StorageService.getInstance();
    _nameControllers[0].text = storage.name;
    _players[0] = {'name': storage.name, 'flag': storage.flag};
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    _audio.stopHeartbeat();
    super.dispose();
  }

  void _startBattle() {
    // Collect player data
    for (int i = 0; i < _playerCount; i++) {
      final name = _nameControllers[i].text.trim();
      if (name.isEmpty) return;
      _players[i]['name'] = name;
    }

    _targetTime = PrecisionCalculator.generateTarget();
    _roundResults.clear();
    _currentPlayerIdx = 0;

    setState(() {
      _phase = _BattlePhase.focus;
    });
  }

  void _onReady() {
    setState(() => _phase = _BattlePhase.countdown);
  }

  void _startTiming() {
    setState(() => _phase = _BattlePhase.timing);
    _stopwatch.reset();
    _stopwatch.start();
    _audio.startHeartbeat(speed: 0.8);
  }

  void _onTap() {
    if (_phase != _BattlePhase.timing) return;

    _stopwatch.stop();
    _audio.stopHeartbeat();
    HapticFeedback.heavyImpact();

    final actualTime = _stopwatch.elapsedMilliseconds / 1000.0;
    final roundedActual = (actualTime * 100).round() / 100.0;

    final result = GameResult(
      targetTime: _targetTime,
      actualTime: roundedActual,
      playerName: _players[_currentPlayerIdx]['name']!,
    );
    _roundResults.add(result);
    _allResults.add(result);

    _currentPlayerIdx++;

    if (_currentPlayerIdx >= _playerCount) {
      // All players done — show results
      _showBattleResults();
    } else {
      setState(() => _phase = _BattlePhase.pass);
    }
  }

  void _nextPlayer() {
    setState(() => _phase = _BattlePhase.focus);
  }

  void _showBattleResults() {
    // Sort results by precision
    final sorted = List<GameResult>.from(_roundResults);
    sorted.sort((a, b) => a.absDifference.compareTo(b.absDifference));

    Navigator.of(context).pushReplacement(
      AppTheme.fadeRoute(RevealScreen(
        result: sorted.first,
        isBattle: true,
        allResults: _roundResults,
        onPlayAgain: () {
          Navigator.of(context).pushReplacement(
            AppTheme.fadeRoute(const BattleModeScreen()),
          );
        },
      )),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: _phase == _BattlePhase.setup ? _buildSetup() : _buildGameplay(),
      ),
    );
  }

  Widget _buildSetup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Back button
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
          const SizedBox(height: 20),
          Text('BATTLE MODE', style: AppTheme.headingMedium.copyWith(letterSpacing: 3)),
          const SizedBox(height: 8),
          Text('Pass & destroy', style: AppTheme.bodyMedium),
          const SizedBox(height: 24),

          // Player count selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((count) {
              final selected = _playerCount == count;
              return GestureDetector(
                onTap: () => setState(() => _playerCount = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.cyan.withValues(alpha: 0.15) : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.cyan : AppTheme.dimWhite.withValues(alpha: 0.15),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: AppTheme.cyan.withValues(alpha: 0.3), blurRadius: 10)]
                        : null,
                  ),
                  child: Text(
                    '$count',
                    style: AppTheme.headingSmall.copyWith(
                      color: selected ? AppTheme.cyan : AppTheme.dimWhite,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Text('PLAYERS', style: AppTheme.labelStyle),
          const SizedBox(height: 20),

          // Player name inputs
          Expanded(
            child: ListView.builder(
              itemCount: _playerCount,
              itemBuilder: (context, i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.neonBorder(
                    color: AppTheme.cyan.withValues(alpha: 0.3),
                    borderRadius: 12,
                  ),
                  child: Row(
                    children: [
                      // Flag selector
                      GestureDetector(
                        onTap: () {
                          _showFlagPicker(i);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.surfaceDark,
                            border: Border.all(color: AppTheme.dimWhite.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Text(
                              _players[i]['flag'] ?? _flags[i],
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nameControllers[i],
                          style: AppTheme.bodyLarge,
                          cursorColor: AppTheme.cyan,
                          decoration: InputDecoration(
                            hintText: 'Player ${i + 1}',
                            hintStyle: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.dimWhite.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          GlowButton(
            text: 'START BATTLE',
            onTap: _startBattle,
            color: AppTheme.cyan,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showFlagPicker(int playerIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _flags.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  setState(() => _players[playerIdx]['flag'] = _flags[i]);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_flags[i], style: const TextStyle(fontSize: 28)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGameplay() {
    switch (_phase) {
      case _BattlePhase.focus:
        return _buildFocusScreen();
      case _BattlePhase.ready:
        return _buildFocusScreen();
      case _BattlePhase.countdown:
        return Center(child: CountdownWidget(onComplete: _startTiming));
      case _BattlePhase.timing:
        return _buildTimingScreen();
      case _BattlePhase.pass:
        return _buildPassScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFocusScreen() {
    final playerName = _players[_currentPlayerIdx]['name'] ?? 'Player';
    final playerFlag = _players[_currentPlayerIdx]['flag'] ?? '🏳️';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(playerFlag, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            playerName.toUpperCase(),
            style: AppTheme.headingLarge.copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 8),
          Text(
            'FOCUS',
            style: AppTheme.labelStyle.copyWith(
              color: AppTheme.cyan,
              letterSpacing: 6,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Others look away',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.dimWhite.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'TARGET: ${PrecisionCalculator.formatTime(_targetTime)}s',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 30),
          GlowButton(
            text: 'READY',
            onTap: _onReady,
            color: AppTheme.cyan,
            width: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildTimingScreen() {
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
                      color: AppTheme.cyan.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyan.withValues(alpha: _pulseAnimation.value),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'TAP',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.cyan,
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

  Widget _buildPassScreen() {
    final nextName = _currentPlayerIdx < _playerCount
        ? _players[_currentPlayerIdx]['name'] ?? 'Next Player'
        : '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PASS TO',
            style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          Text(
            nextName.toUpperCase(),
            style: AppTheme.headingLarge.copyWith(
              color: AppTheme.cyan,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 40),
          GlowButton(
            text: 'READY',
            onTap: _nextPlayer,
            color: AppTheme.cyan,
            width: 200,
          ),
        ],
      ),
    );
  }
}
