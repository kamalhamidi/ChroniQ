import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PrecisionTier {
  godlike(0.000, 0.030, '⚡', 'GODLIKE', AppTheme.purple),
  perfect(0.031, 0.080, '💫', 'PERFECT', AppTheme.cyan),
  great(0.081, 0.150, '✅', 'GREAT', AppTheme.green),
  good(0.151, 0.300, '🟡', 'GOOD', AppTheme.amber),
  ok(0.301, 0.500, '🟠', 'OK', AppTheme.orange),
  bad(0.501, double.infinity, '💀', 'BAD', AppTheme.red);

  final double minDiff;
  final double maxDiff;
  final String emoji;
  final String displayName;
  final Color color;

  const PrecisionTier(this.minDiff, this.maxDiff, this.emoji, this.displayName, this.color);

  static PrecisionTier fromDifference(double absDifference) {
    for (final tier in PrecisionTier.values) {
      if (absDifference >= tier.minDiff && absDifference <= tier.maxDiff) {
        return tier;
      }
    }
    return PrecisionTier.bad;
  }
}

class GameResult {
  final double targetTime;
  final double actualTime;
  final double difference; // signed: negative = early, positive = late
  final double absDifference;
  final PrecisionTier tier;
  final String playerName;
  final DateTime timestamp;

  GameResult({
    required this.targetTime,
    required this.actualTime,
    required this.playerName,
    DateTime? timestamp,
  })  : difference = actualTime - targetTime,
        absDifference = (actualTime - targetTime).abs(),
        tier = PrecisionTier.fromDifference((actualTime - targetTime).abs()),
        timestamp = timestamp ?? DateTime.now();

  bool get isEarly => difference < 0;
  bool get isLate => difference > 0;
  bool get isPerfect => absDifference < 0.001;

  String get differenceText {
    if (isPerfect) return 'PERFECT';
    final prefix = isEarly ? 'early' : 'late';
    return '${absDifference.toStringAsFixed(2)}s $prefix';
  }

  Map<String, dynamic> toJson() => {
        'targetTime': targetTime,
        'actualTime': actualTime,
        'playerName': playerName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
        targetTime: (json['targetTime'] as num).toDouble(),
        actualTime: (json['actualTime'] as num).toDouble(),
        playerName: json['playerName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
