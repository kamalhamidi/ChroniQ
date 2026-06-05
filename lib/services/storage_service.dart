import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rank.dart';

class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── Keys ──
  static const _keyName = 'chrono_name';
  static const _keyFlag = 'chrono_flag';
  static const _keyUsername = 'chrono_username';
  static const _keyFirstLaunch = 'chrono_first_launch';
  static const _keyTotalGames = 'chrono_total_games';
  static const _keyPrecisionHistory = 'chrono_precision_history';
  static const _keyBestPrecision = 'chrono_best_precision';
  static const _keyStreak = 'chrono_streak';
  static const _keyRank = 'chrono_rank';
  static const _keyDailyLastDate = 'chrono_daily_last_date';
  static const _keyDailyResult = 'chrono_daily_result';
  static const _keyUnlockedAbilities = 'chrono_unlocked_abilities';
  static const _keyStreakMultiplierHighScore = 'streak_multiplier_high_score';
  static const _keyRhythmBestAvgMs = 'rhythm_best_avg_ms';
  static const _keyBlindBestPrecision = 'blind_best_precision';
  static const _keyGauntletHighScore = 'gauntlet_high_score';
  static const _keyZonesBestPrecision = 'zones_best_precision';
  static const _keyZonesTooltipSeen = 'zones_tooltip_seen';

  // ── First Launch ──
  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchDone() async {
    await _prefs.setBool(_keyFirstLaunch, false);
  }

  // ── Profile ──
  Future<void> saveProfile({
    required String name,
    required String flag,
    required String username,
  }) async {
    await _prefs.setString(_keyName, name);
    await _prefs.setString(_keyFlag, flag);
    await _prefs.setString(_keyUsername, username);
  }

  String get name => _prefs.getString(_keyName) ?? 'Player';
  String get flag => _prefs.getString(_keyFlag) ?? '🏳️';
  String get username => _prefs.getString(_keyUsername) ?? 'player';

  // ── Game Stats ──
  int get totalGames => _prefs.getInt(_keyTotalGames) ?? 0;
  int get streak => _prefs.getInt(_keyStreak) ?? 0;
  double get bestPrecision => _prefs.getDouble(_keyBestPrecision) ?? 999.0;

  List<double> get precisionHistory {
    final jsonStr = _prefs.getString(_keyPrecisionHistory);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => (e as num).toDouble()).toList();
  }

  double get averagePrecision {
    final history = precisionHistory;
    if (history.isEmpty) return 999.0;
    return history.reduce((a, b) => a + b) / history.length;
  }

  Rank get currentRank => Rank.fromAverage(averagePrecision);

  Future<void> addGameResult(double absDifference) async {
    // Update total games
    await _prefs.setInt(_keyTotalGames, totalGames + 1);

    // Update precision history (keep last 50)
    final history = precisionHistory;
    history.add(absDifference);
    if (history.length > 50) {
      history.removeAt(0);
    }
    await _prefs.setString(_keyPrecisionHistory, jsonEncode(history));

    // Update best precision
    if (absDifference < bestPrecision) {
      await _prefs.setDouble(_keyBestPrecision, absDifference);
    }

    // Update streak
    if (absDifference <= 0.150) {
      // GREAT or better maintains streak
      await _prefs.setInt(_keyStreak, streak + 1);
    } else {
      await _prefs.setInt(_keyStreak, 0);
    }

    // Update rank
    final newRank = Rank.fromAverage(averagePrecision);
    final oldRankIndex = _prefs.getInt(_keyRank) ?? 0;
    await _prefs.setInt(_keyRank, newRank.index);

    // Check for ability unlocks based on rank
    await _checkAbilityUnlocks(newRank);

    // Return whether rank changed (for rank-up animation)
    if (newRank.index > oldRankIndex) {
      // Rank up happened - caller should check
    }
  }

  Future<bool> didRankUp(Rank newRank) async {
    final oldRankIndex = _prefs.getInt(_keyRank) ?? 0;
    return newRank.index > oldRankIndex;
  }

  // ── Daily Challenge ──
  bool isDailyPlayed() {
    final lastDate = _prefs.getString(_keyDailyLastDate);
    if (lastDate == null) return false;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return lastDate == todayStr;
  }

  Future<void> saveDailyResult(double result) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await _prefs.setString(_keyDailyLastDate, todayStr);
    await _prefs.setDouble(_keyDailyResult, result);
  }

  double? get lastDailyResult => _prefs.getDouble(_keyDailyResult);

  // ── Focus Abilities ──
  List<String> get unlockedAbilities {
    final jsonStr = _prefs.getString(_keyUnlockedAbilities);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.cast<String>();
  }

  Future<void> unlockAbility(String ability) async {
    final abilities = unlockedAbilities;
    if (!abilities.contains(ability)) {
      abilities.add(ability);
      await _prefs.setString(_keyUnlockedAbilities, jsonEncode(abilities));
    }
  }

  // ── Streak Multiplier ──
  int get streakMultiplierHighScore =>
      _prefs.getInt(_keyStreakMultiplierHighScore) ?? 0;

  Future<void> saveStreakMultiplierHighScore(int score) async {
    if (score > streakMultiplierHighScore) {
      await _prefs.setInt(_keyStreakMultiplierHighScore, score);
    }
  }

  // ── Rhythm Challenge ──
  double get rhythmBestScore =>
      _prefs.getDouble(_keyRhythmBestAvgMs) ?? 999.0;

  Future<void> saveRhythmBestScore(double avgMs) async {
    if (avgMs < rhythmBestScore) {
      await _prefs.setDouble(_keyRhythmBestAvgMs, avgMs);
    }
  }

  // ── Blindfolded Mode ──
  double get blindBestPrecision =>
      _prefs.getDouble(_keyBlindBestPrecision) ?? 999.0;

  Future<void> saveBlindBestPrecision(double diff) async {
    if (diff < blindBestPrecision) {
      await _prefs.setDouble(_keyBlindBestPrecision, diff);
    }
  }

  // ── Reflex Gauntlet ──
  int get gauntletHighScore => _prefs.getInt(_keyGauntletHighScore) ?? 0;

  Future<void> saveGauntletHighScore(int hits) async {
    if (hits > gauntletHighScore) {
      await _prefs.setInt(_keyGauntletHighScore, hits);
    }
  }

  // ── Target Zones ──
  double get zonesBestPrecision =>
      _prefs.getDouble(_keyZonesBestPrecision) ?? 999.0;

  Future<void> saveZonesBestPrecision(double diff) async {
    if (diff < zonesBestPrecision) {
      await _prefs.setDouble(_keyZonesBestPrecision, diff);
    }
  }

  bool get zonesTooltipSeen => _prefs.getBool(_keyZonesTooltipSeen) ?? false;

  Future<void> setZonesTooltipSeen() async {
    await _prefs.setBool(_keyZonesTooltipSeen, true);
  }

  Future<void> _checkAbilityUnlocks(Rank rank) async {
    switch (rank) {
      case Rank.silver:
        await unlockAbility('zen_mode');
        break;
      case Rank.gold:
        await unlockAbility('zen_mode');
        await unlockAbility('slow_heartbeat');
        break;
      case Rank.diamond:
        await unlockAbility('zen_mode');
        await unlockAbility('slow_heartbeat');
        await unlockAbility('ghost_tap');
        break;
      case Rank.master:
      case Rank.chronoGod:
        await unlockAbility('zen_mode');
        await unlockAbility('slow_heartbeat');
        await unlockAbility('ghost_tap');
        await unlockAbility('pressure');
        break;
      default:
        break;
    }
  }
}
