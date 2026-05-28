import 'dart:math';

class DailySeed {
  /// Generate a deterministic target time from the current date
  static double getDailyTarget(DateTime date) {
    final seed = date.day * date.month + date.year;
    final rng = Random(seed);
    
    while (true) {
      final raw = 100 + rng.nextInt(900); // 1.00 to 9.99
      final hundredths = raw % 100;
      if (hundredths == 0 || hundredths == 50) continue;
      return raw / 100.0;
    }
  }

  /// Get duration until next midnight (next challenge reset)
  static Duration getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Format duration as HH:MM:SS countdown
  static String formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
