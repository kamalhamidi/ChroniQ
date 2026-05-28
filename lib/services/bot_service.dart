import 'dart:async';
import 'dart:math';
import '../models/bot_player.dart';
import '../models/game_result.dart';

class BotService {
  static BotService? _instance;
  final Random _rng = Random();
  late List<BotPlayer> _activeBots;

  BotService._() {
    _activeBots = [];
  }

  static BotService getInstance() {
    _instance ??= BotService._();
    return _instance!;
  }

  /// Get random bots from the pool
  List<BotPlayer> getRandomBots(int count) {
    final pool = List<BotPlayer>.from(BotPlayer.botPool);
    pool.shuffle(_rng);
    _activeBots = pool.take(count).map((b) => BotPlayer(
      username: b.username,
      flagEmoji: b.flagEmoji,
      personality: b.personality,
      fakeDelay: b.fakeDelay,
      hasRageQuit: false,
      isOnline: true,
    )).toList();
    return _activeBots;
  }

  /// Simulate a bot playing - returns Future that resolves after fake delay
  Future<GameResult> simulateBotResult(
    BotPlayer bot,
    double targetTime,
    int roundNumber,
  ) async {
    await Future.delayed(Duration(milliseconds: bot.fakeDelay));

    // Check for rage quit
    if (bot.personality == BotPersonality.rageQuitter && roundNumber > 1) {
      if (_rng.nextDouble() < 0.3) {
        bot.hasRageQuit = true;
        bot.isOnline = false;
        // Return a very bad result
        return GameResult(
          targetTime: targetTime,
          actualTime: targetTime + 99.0,
          playerName: bot.username,
        );
      }
    }

    final actualTime = bot.getActualTime(targetTime, roundNumber);
    return GameResult(
      targetTime: targetTime,
      actualTime: actualTime.clamp(0.01, 99.99),
      playerName: bot.username,
    );
  }

  /// Get random fake chat messages
  List<MapEntry<String, String>> getRandomChatMessages(List<BotPlayer> bots, {int count = 2}) {
    final messages = <MapEntry<String, String>>[];
    final pool = List<String>.from(BotPlayer.fakeChatMessages)..shuffle(_rng);
    final botList = List<BotPlayer>.from(bots)..shuffle(_rng);

    for (int i = 0; i < count && i < pool.length && i < botList.length; i++) {
      messages.add(MapEntry(botList[i].username, pool[i]));
    }
    return messages;
  }

  /// Generate fake daily leaderboard entries
  List<Map<String, dynamic>> generateFakeLeaderboard(double userResult, int count) {
    final entries = <Map<String, dynamic>>[];
    final pool = List<BotPlayer>.from(BotPlayer.botPool)..shuffle(_rng);

    for (int i = 0; i < count && i < pool.length * 3; i++) {
      final bot = pool[i % pool.length];
      // Generate results clustered around the user's result
      final offset = (_rng.nextDouble() - 0.4) * 0.8; // Bias slightly better
      final fakeResult = (userResult + offset).abs();

      entries.add({
        'username': '${bot.username}${i > pool.length ? '_${_rng.nextInt(99)}' : ''}',
        'flag': bot.flagEmoji,
        'result': (fakeResult * 100).round() / 100.0,
        'isUser': false,
      });
    }

    // Sort by precision (lowest = best)
    entries.sort((a, b) => (a['result'] as double).compareTo(b['result'] as double));

    // Insert user at correct position
    final userEntry = {
      'username': 'YOU',
      'flag': '⭐',
      'result': (userResult * 100).round() / 100.0,
      'isUser': true,
    };

    int insertIdx = entries.indexWhere((e) => (e['result'] as double) > userResult);
    if (insertIdx == -1) insertIdx = entries.length;
    entries.insert(insertIdx, userEntry);

    // Keep only `count` entries centered around user
    if (entries.length > count) {
      final userPos = entries.indexOf(userEntry);
      final start = (userPos - count ~/ 2).clamp(0, entries.length - count);
      return entries.sublist(start, start + count);
    }

    return entries;
  }

  /// Generate fake ping value
  int generateFakePing() {
    return 15 + _rng.nextInt(85); // 15-100ms
  }

  /// Bot reaction emoji based on result
  String getBotReaction(BotPlayer bot, GameResult botResult, GameResult userResult) {
    if (botResult.absDifference < userResult.absDifference) {
      // Bot won
      return _rng.nextBool() ? '😎 GG' : '🔥 easy';
    } else {
      // Bot lost
      if (bot.personality == BotPersonality.rageQuitter) {
        return '😤 no way';
      }
      final reactions = ['😤 no way', '💀 gg', '😢 close', '🤯 how'];
      return reactions[_rng.nextInt(reactions.length)];
    }
  }
}
