import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum Rank {
  bronze(0.400, double.infinity, '🥉', 'BRONZE', AppTheme.orange),
  silver(0.200, 0.400, '🥈', 'SILVER', Color(0xFFC0C0C0)),
  gold(0.100, 0.200, '🥇', 'GOLD', AppTheme.amber),
  diamond(0.050, 0.100, '💎', 'DIAMOND', AppTheme.cyan),
  master(0.020, 0.050, '👑', 'MASTER', AppTheme.purple),
  chronoGod(0.000, 0.020, '⚡', 'CHRONO GOD', Color(0xFFFF00FF));

  final double minAvg;
  final double maxAvg;
  final String emoji;
  final String displayName;
  final Color color;

  const Rank(this.minAvg, this.maxAvg, this.emoji, this.displayName, this.color);

  static Rank fromAverage(double avgPrecision) {
    if (avgPrecision < 0.020) return Rank.chronoGod;
    if (avgPrecision < 0.050) return Rank.master;
    if (avgPrecision < 0.100) return Rank.diamond;
    if (avgPrecision < 0.200) return Rank.gold;
    if (avgPrecision < 0.400) return Rank.silver;
    return Rank.bronze;
  }

  /// Progress percentage toward next rank (0.0 to 1.0)
  double progressToNext(double currentAvg) {
    if (this == Rank.chronoGod) return 1.0;

    final nextRank = Rank.values[index + 1];
    final currentRankMax = maxAvg == double.infinity ? 1.0 : maxAvg;
    final nextRankMax = nextRank.maxAvg;
    
    // How far we are within our rank range towards the next rank
    final range = currentRankMax - nextRankMax;
    if (range <= 0) return 1.0;
    
    final progress = (currentRankMax - currentAvg) / range;
    return progress.clamp(0.0, 1.0);
  }

  /// Get the next rank (or null if already max)
  Rank? get nextRank {
    final idx = Rank.values.indexOf(this);
    if (idx >= Rank.values.length - 1) return null;
    return Rank.values[idx + 1];
  }
}
