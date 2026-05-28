import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../models/rank.dart';
import '../widgets/rank_badge.dart';
import '../widgets/neon_progress_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _flag = '';
  String _username = '';
  Rank _rank = Rank.bronze;
  int _totalGames = 0;
  double _avgPrecision = 0.0;
  double _bestPrecision = 0.0;
  int _streak = 0;
  List<double> _history = [];
  List<String> _unlockedAbilities = [];
  double _rankProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storage = await StorageService.getInstance();
    if (!mounted) return;
    setState(() {
      _name = storage.name;
      _flag = storage.flag;
      _username = storage.username;
      _rank = storage.currentRank;
      _totalGames = storage.totalGames;
      _avgPrecision = storage.averagePrecision;
      _bestPrecision = storage.bestPrecision;
      _streak = storage.streak;
      _history = storage.precisionHistory;
      _unlockedAbilities = storage.unlockedAbilities;
      _rankProgress = _rank.progressToNext(_avgPrecision);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: SingleChildScrollView(
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

              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardBg,
                  border: Border.all(color: _rank.color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _rank.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(_flag, style: const TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 12),
              Text(_name, style: AppTheme.headingMedium),
              Text(
                '@$_username',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.dimWhite),
              ),
              const SizedBox(height: 12),
              RankBadge(rank: _rank, size: 52),
              const SizedBox(height: 6),
              Text(
                _rank.displayName,
                style: AppTheme.headingSmall.copyWith(
                  color: _rank.color,
                  letterSpacing: 2,
                ),
              ),

              // Rank progress
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: NeonProgressBar(
                  progress: _rankProgress,
                  color: _rank.color,
                  label: _rank.nextRank != null
                      ? 'Progress to ${_rank.nextRank!.displayName}'
                      : 'MAX RANK',
                ),
              ),

              // Stats grid
              const SizedBox(height: 28),
              Text(
                'STATISTICS',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('TOTAL GAMES', '$_totalGames', AppTheme.purple),
                  _buildStatCard(
                    'AVG PRECISION',
                    _totalGames > 0 ? '${_avgPrecision.toStringAsFixed(3)}s' : '—',
                    AppTheme.cyan,
                  ),
                  _buildStatCard(
                    'BEST EVER',
                    _bestPrecision < 900 ? '${_bestPrecision.toStringAsFixed(3)}s' : '—',
                    AppTheme.green,
                  ),
                  _buildStatCard('STREAK', '$_streak', AppTheme.amber),
                ],
              ),

              // Accuracy chart
              if (_history.length >= 2) ...[
                const SizedBox(height: 28),
                Text(
                  'RECENT ACCURACY',
                  style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.neonBorder(color: AppTheme.purple.withValues(alpha: 0.3)),
                  child: _buildChart(),
                ),
              ],

              // Focus Abilities
              const SizedBox(height: 28),
              Text(
                'FOCUS ABILITIES',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 14),
              _buildAbilitiesGrid(),

              // Achievements
              const SizedBox(height: 28),
              Text(
                'ACHIEVEMENTS',
                style: AppTheme.labelStyle.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 14),
              _buildAchievementsGrid(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.neonBorder(color: color.withValues(alpha: 0.3)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(
              color: color,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 10,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final last10 = _history.length > 10
        ? _history.sublist(_history.length - 10)
        : _history;

    final spots = last10.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.dimWhite.withValues(alpha: 0.08),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}s',
                  style: AppTheme.bodySmall.copyWith(fontSize: 9),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.purple,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.purple,
                  strokeWidth: 1,
                  strokeColor: AppTheme.cyan,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.purple.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppTheme.surfaceDark,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(3)}s',
                  AppTheme.bodySmall.copyWith(color: AppTheme.purple),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAbilitiesGrid() {
    final abilities = [
      {
        'id': 'zen_mode',
        'name': 'Zen Mode',
        'emoji': '🧘',
        'desc': 'Disables pulse animations',
        'rank': 'SILVER',
      },
      {
        'id': 'slow_heartbeat',
        'name': 'Slow Heartbeat',
        'emoji': '🐢',
        'desc': 'Heartbeat is calmer',
        'rank': 'GOLD',
      },
      {
        'id': 'ghost_tap',
        'name': 'Ghost Tap',
        'emoji': '👻',
        'desc': 'No press animation',
        'rank': 'DIAMOND',
      },
      {
        'id': 'pressure',
        'name': 'Pressure',
        'emoji': '💥',
        'desc': 'Opponent vibrates on tap',
        'rank': 'MASTER',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: abilities.length,
      itemBuilder: (context, i) {
        final ability = abilities[i];
        final isUnlocked = _unlockedAbilities.contains(ability['id']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? AppTheme.cardBg : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? AppTheme.purple.withValues(alpha: 0.4)
                  : AppTheme.dimWhite.withValues(alpha: 0.1),
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: AppTheme.purple.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ability['emoji'] as String,
                style: TextStyle(
                  fontSize: 24,
                  color: isUnlocked ? null : AppTheme.dimWhite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ability['name'] as String,
                style: AppTheme.bodySmall.copyWith(
                  color: isUnlocked ? AppTheme.white : AppTheme.dimWhite,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                isUnlocked ? ability['desc'] as String : 'Unlock at ${ability['rank']}',
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 9,
                  color: AppTheme.dimWhite.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAchievementsGrid() {
    final achievements = [
      {'name': 'First Timer', 'emoji': '🎯', 'req': _totalGames >= 1},
      {'name': 'Veteran', 'emoji': '⭐', 'req': _totalGames >= 50},
      {'name': 'GODLIKE Once', 'emoji': '⚡', 'req': _bestPrecision < 0.03 && _bestPrecision > 0},
      {'name': 'Streak 5', 'emoji': '🔥', 'req': _streak >= 5},
      {'name': 'Streak 10', 'emoji': '💎', 'req': _streak >= 10},
      {'name': 'Silver Rank', 'emoji': '🥈', 'req': _rank.index >= Rank.silver.index},
      {'name': 'Gold Rank', 'emoji': '🥇', 'req': _rank.index >= Rank.gold.index},
      {'name': 'Diamond Rank', 'emoji': '💎', 'req': _rank.index >= Rank.diamond.index},
      {'name': 'Master Rank', 'emoji': '👑', 'req': _rank.index >= Rank.master.index},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, i) {
        final ach = achievements[i];
        final unlocked = ach['req'] as bool;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: unlocked ? AppTheme.cardBg : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: unlocked
                  ? AppTheme.cyan.withValues(alpha: 0.4)
                  : AppTheme.dimWhite.withValues(alpha: 0.08),
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: AppTheme.cyan.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ColorFiltered(
                colorFilter: unlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 0.4, 0,
                      ]),
                child: Text(
                  ach['emoji'] as String,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ach['name'] as String,
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 9,
                  color: unlocked ? AppTheme.white : AppTheme.dimWhite.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
