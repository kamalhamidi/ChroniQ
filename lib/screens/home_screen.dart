import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/rank.dart';
import '../widgets/rank_badge.dart';
import '../utils/daily_seed.dart';
import 'precision_mode_screen.dart';
import 'battle_mode_screen.dart';
import 'online_mode_screen.dart';
import 'daily_challenge_screen.dart';
import 'streak_multiplier_screen.dart';
import 'rhythm_challenge_screen.dart';
import 'blindfolded_mode_screen.dart';
import 'reflex_gauntlet_screen.dart';
import 'target_zones_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late VideoPlayerController _videoController;

  String _name = '';
  String _flag = '';
  Rank _rank = Rank.bronze;
  bool _dailyPlayed = false;
  String _dailyCountdown = '';
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _loadProfile();

    _videoController = VideoPlayerController.asset('assets/bg_video.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
        if (mounted) setState(() {});
      });
  }

  Future<void> _loadProfile() async {
    final storage = await StorageService.getInstance();
    if (!mounted) return;
    setState(() {
      _name = storage.name;
      _flag = storage.flag;
      _rank = storage.currentRank;
      _dailyPlayed = storage.isDailyPlayed();
    });

    if (_dailyPlayed) {
      _startDailyCountdown();
    }
  }

  void _startDailyCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (!mounted) return;
    setState(() {
      _dailyCountdown = DailySeed.formatCountdown(DailySeed.getTimeUntilReset());
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _fadeController.dispose();
    _videoController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(AppTheme.fadeRoute(screen)).then((_) {
      _loadProfile(); // Refresh on return
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _videoController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Container(color: AppTheme.black),
          ),
          // subtle overlay to keep text readable
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ── Top: Avatar + Rank ──
                    Row(
                      children: [
                        // Avatar circle
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.cardBg,
                            border: Border.all(
                              color: AppTheme.purple.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: AppTheme.headingSmall.copyWith(fontSize: 16),
                            ),
                            Text(
                              _rank.displayName,
                              style: AppTheme.bodySmall.copyWith(
                                color: _rank.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        RankBadge(rank: _rank, size: 44),
                      ],
                    ),

                    const Spacer(),

                    // ── Center: CHRONO Logo ──
                    AnimatedBuilder(
                      animation: _breatheAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _breatheAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'CHRONIQ',
                          style: AppTheme.headingXL.copyWith(
                            letterSpacing: 10,
                            shadows: [
                              Shadow(
                                color: AppTheme.purple.withValues(alpha: 0.7),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'TIMING PRECISION',
                      style: AppTheme.labelStyle.copyWith(
                        color: AppTheme.dimWhite.withValues(alpha: 0.5),
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Mode Cards ──
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildModeCard(
                              title: 'PRECISION',
                              subtitle: 'Train your inner clock',
                              color: AppTheme.purple,
                              onTap: () => _navigateTo(const PrecisionModeScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'BATTLE',
                              subtitle: 'Pass & destroy friends',
                              color: AppTheme.cyan,
                              onTap: () => _navigateTo(const BattleModeScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'ONLINE',
                              subtitle: 'Match with players worldwide',
                              color: AppTheme.green,
                              onTap: () => _navigateTo(const OnlineModeScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'DAILY CHALLENGE',
                              subtitle: _dailyPlayed
                                  ? 'Next in $_dailyCountdown'
                                  : 'One shot. One chance.',
                              color: AppTheme.amber,
                              onTap: () => _navigateTo(const DailyChallengeScreen()),
                              disabled: _dailyPlayed,
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'STREAK MULTIPLIER',
                              subtitle: 'Build your combo. Don\'t break the chain.',
                              color: const Color(0xFF00FFFF),
                              icon: Icons.bolt,
                              onTap: () => _navigateTo(const StreakMultiplierScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'RHYTHM CHALLENGE',
                              subtitle: 'Hit every beat. Feel the sequence.',
                              color: const Color(0xFFBF5FFF),
                              icon: Icons.music_note,
                              onTap: () => _navigateTo(const RhythmChallengeScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'BLINDFOLDED',
                              subtitle: 'No numbers. Pure instinct.',
                              color: const Color(0xFFFF3B3B),
                              icon: Icons.visibility_off,
                              locked: _rank.index < Rank.gold.index,
                              onTap: () => _navigateTo(const BlindfoldedModeScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'REFLEX GAUNTLET',
                              subtitle: '60 seconds. No mercy.',
                              color: const Color(0xFFFF6B00),
                              icon: Icons.timer,
                              onTap: () => _navigateTo(const ReflexGauntletScreen()),
                            ),
                            const SizedBox(height: 12),
                            _buildModeCard(
                              title: 'TARGET ZONES',
                              subtitle: 'Narrow it down. Find your range.',
                              color: const Color(0xFF00FF88),
                              icon: Icons.center_focus_strong,
                              onTap: () => _navigateTo(const TargetZonesScreen()),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Bottom: Profile ──
                    GestureDetector(
                      onTap: () => _navigateTo(const ProfileScreen()),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.cardBg,
                          border: Border.all(
                            color: AppTheme.dimWhite.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppTheme.dimWhite,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
    IconData? icon,
    bool locked = false,
  }) {
    final isInactive = disabled || locked;
    final effectiveColor = isInactive ? color.withValues(alpha: 0.3) : color;

    return GestureDetector(
      onTap: () {
        if (disabled) return;
        if (locked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reach Gold rank to unlock Blindfolded Mode'),
              backgroundColor: AppTheme.cardBg,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        onTap();
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, scale, child) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: AppTheme.neonLeftBorder(color: effectiveColor),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: effectiveColor, size: 22),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTheme.headingSmall.copyWith(
                              color: isInactive ? AppTheme.dimWhite : AppTheme.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTheme.bodySmall.copyWith(
                              color: isInactive
                                  ? AppTheme.dimWhite.withValues(alpha: 0.5)
                                  : AppTheme.dimWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      locked ? Icons.lock : Icons.chevron_right,
                      color: isInactive
                          ? AppTheme.dimWhite.withValues(alpha: 0.3)
                          : color,
                      size: 24,
                    ),
                  ],
                ),
              ),
              if (locked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: color.withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Unlock at Gold Rank',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
