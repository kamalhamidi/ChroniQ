import 'dart:math';
import '../models/game_result.dart';

class PrecisionCalculator {
  static final Random _rng = Random();

  /// Calculate signed difference (negative = early, positive = late)
  static double calculateDifference(double target, double actual) {
    return actual - target;
  }

  /// Get precision tier from absolute difference
  static PrecisionTier getTier(double absDifference) {
    return PrecisionTier.fromDifference(absDifference);
  }

  /// Generate a random target time between 1.00 and 9.99 seconds
  /// Never generates .00 or .50 endings
  static double generateTarget() {
    while (true) {
      // Generate random value between 100 and 999 (representing 1.00 to 9.99)
      final raw = 100 + _rng.nextInt(900);
      final value = raw / 100.0;

      // Check for forbidden endings
      final hundredths = raw % 100;
      if (hundredths == 0 || hundredths == 50) continue;

      return value;
    }
  }

  /// Format time to 2 decimal places
  static String formatTime(double seconds) {
    return seconds.toStringAsFixed(2);
  }

  /// Format difference with sign
  static String formatDifference(double difference) {
    if (difference.abs() < 0.005) return 'PERFECT';
    final prefix = difference < 0 ? '-' : '+';
    return '$prefix${difference.abs().toStringAsFixed(2)}s';
  }
}
