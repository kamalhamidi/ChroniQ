import 'dart:math';

enum BotPersonality {
  tooFast,   // always early: -0.1 to -0.4s
  slowBro,   // always late: +0.2 to +0.6s
  zenTimer,  // very accurate: ±0.01 to ±0.08s
  chaotic,   // random: ±0.1 to ±0.9s
  clutch,    // degrades each round: +0.05s per round
  rageQuitter, // leaves after losing
}

class BotPlayer {
  final String username;
  final String flagEmoji;
  final BotPersonality personality;
  final int fakeDelay; // ms before result "arrives"
  bool hasRageQuit;
  bool isOnline;

  BotPlayer({
    required this.username,
    required this.flagEmoji,
    required this.personality,
    required this.fakeDelay,
    this.hasRageQuit = false,
    this.isOnline = true,
  });

  /// Generate timing offset based on personality and round number
  double generateOffset(double targetTime, int roundNumber) {
    final rng = Random();

    switch (personality) {
      case BotPersonality.tooFast:
        // Always early: -0.1 to -0.4s
        return -(0.1 + rng.nextDouble() * 0.3);

      case BotPersonality.slowBro:
        // Always late: +0.2 to +0.6s
        return 0.2 + rng.nextDouble() * 0.4;

      case BotPersonality.zenTimer:
        // Very accurate: ±0.01 to ±0.08s
        final offset = 0.01 + rng.nextDouble() * 0.07;
        return rng.nextBool() ? offset : -offset;

      case BotPersonality.chaotic:
        // Random: ±0.1 to ±0.9s
        final offset = 0.1 + rng.nextDouble() * 0.8;
        return rng.nextBool() ? offset : -offset;

      case BotPersonality.clutch:
        // Gets worse each round: base ±0.03 + 0.05s per round
        final base = 0.03 + rng.nextDouble() * 0.05;
        final degradation = roundNumber * 0.05;
        final offset = base + degradation;
        return rng.nextBool() ? offset : -offset;

      case BotPersonality.rageQuitter:
        // Starts decent, but may rage quit
        final offset = 0.05 + rng.nextDouble() * 0.15;
        return rng.nextBool() ? offset : -offset;
    }
  }

  double getActualTime(double targetTime, int roundNumber) {
    final offset = generateOffset(targetTime, roundNumber);
    final actual = targetTime + offset;
    // Clamp to reasonable range
    return (actual * 100).round() / 100.0;
  }

  static final List<BotPlayer> botPool = [
    BotPlayer(username: 'xTimer_99', flagEmoji: '🇺🇸', personality: BotPersonality.zenTimer, fakeDelay: 1200),
    BotPlayer(username: 'Zen_Kira', flagEmoji: '🇯🇵', personality: BotPersonality.zenTimer, fakeDelay: 1500),
    BotPlayer(username: 'SlowBroTV', flagEmoji: '🇧🇷', personality: BotPersonality.slowBro, fakeDelay: 2200),
    BotPlayer(username: 'SpeedDemon', flagEmoji: '🇰🇷', personality: BotPersonality.tooFast, fakeDelay: 800),
    BotPlayer(username: 'ChaosMaster', flagEmoji: '🇩🇪', personality: BotPersonality.chaotic, fakeDelay: 1800),
    BotPlayer(username: 'PrecisionX', flagEmoji: '🇬🇧', personality: BotPersonality.zenTimer, fakeDelay: 1100),
    BotPlayer(username: 'TimeLord42', flagEmoji: '🇫🇷', personality: BotPersonality.clutch, fakeDelay: 1400),
    BotPlayer(username: 'QuickFlick', flagEmoji: '🇮🇳', personality: BotPersonality.tooFast, fakeDelay: 900),
    BotPlayer(username: 'SnailPace', flagEmoji: '🇦🇺', personality: BotPersonality.slowBro, fakeDelay: 2500),
    BotPlayer(username: 'RageQuit_lol', flagEmoji: '🇷🇺', personality: BotPersonality.rageQuitter, fakeDelay: 1600),
    BotPlayer(username: 'NanoSec', flagEmoji: '🇨🇦', personality: BotPersonality.zenTimer, fakeDelay: 1300),
    BotPlayer(username: 'WildCard', flagEmoji: '🇲🇽', personality: BotPersonality.chaotic, fakeDelay: 2000),
    BotPlayer(username: 'ClutchKing', flagEmoji: '🇪🇸', personality: BotPersonality.clutch, fakeDelay: 1700),
    BotPlayer(username: 'EZ_Clap', flagEmoji: '🇹🇷', personality: BotPersonality.tooFast, fakeDelay: 1000),
    BotPlayer(username: 'NoChance', flagEmoji: '🇮🇹', personality: BotPersonality.rageQuitter, fakeDelay: 1900),
    BotPlayer(username: 'FlowState', flagEmoji: '🇸🇪', personality: BotPersonality.zenTimer, fakeDelay: 1250),
    BotPlayer(username: 'BuzzSaw', flagEmoji: '🇳🇴', personality: BotPersonality.chaotic, fakeDelay: 1550),
    BotPlayer(username: 'GlitchMode', flagEmoji: '🇵🇱', personality: BotPersonality.clutch, fakeDelay: 1650),
  ];

  static final List<String> fakeChatMessages = [
    'gg',
    'let\'s go 🔥',
    'ez',
    'good luck everyone',
    '😤 ready',
    'this is my game',
    'no mercy',
    '🎯',
    'focus time',
    'im cracked at this',
    'lol',
    'first try 💪',
    'nervous 😅',
    'bring it',
    '⚡ speed',
  ];
}
