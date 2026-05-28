import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/rank.dart';
import '../widgets/rank_badge.dart';
import '../utils/daily_seed.dart';
import 'precision_mode_screen.dart';
import 'battle_mode_screen.dart';
import 'online_mode_screen.dart';
import 'daily_challenge_screen.dart';
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
      body: SafeArea(
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
                        child: Text(_flag, style: const TextStyle(fontSize: 24)),
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
                      'CHRONO',
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

                const Spacer(),

                // ── Mode Cards ──
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

                const Spacer(),

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
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, scale, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: AppTheme.neonLeftBorder(
              color: disabled ? color.withValues(alpha: 0.3) : color,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headingSmall.copyWith(
                          color: disabled ? AppTheme.dimWhite : AppTheme.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(
                          color: disabled
                              ? AppTheme.dimWhite.withValues(alpha: 0.5)
                              : AppTheme.dimWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: disabled ? AppTheme.dimWhite.withValues(alpha: 0.3) : color,
                  size: 24,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
