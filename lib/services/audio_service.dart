import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioService? _instance;
  
  final AudioPlayer _countdownPlayer = AudioPlayer();
  final AudioPlayer _resultPlayer = AudioPlayer();
  final AudioPlayer _heartbeatPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  
  Timer? _heartbeatTimer;
  double _heartbeatSpeed = 1.0;
  bool _heartbeatActive = false;

  AudioService._();

  static AudioService getInstance() {
    _instance ??= AudioService._();
    return _instance!;
  }

  /// Generate a sine wave WAV as bytes
  Uint8List _generateTone({
    required double frequency,
    required double durationMs,
    double volume = 0.5,
    int sampleRate = 22050,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final data = Uint8List(numSamples * 2); // 16-bit mono
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Apply envelope for click-free sound
      double envelope = 1.0;
      final attackSamples = (sampleRate * 0.01).round(); // 10ms attack
      final releaseSamples = (sampleRate * 0.05).round(); // 50ms release
      
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i > numSamples - releaseSamples) {
        envelope = (numSamples - i) / releaseSamples;
      }
      
      final sample = (sin(2 * pi * frequency * t) * 32767 * volume * envelope).round().clamp(-32768, 32767);
      data[i * 2] = sample & 0xFF;
      data[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    
    return _wrapInWav(data, sampleRate);
  }

  /// Wrap raw PCM data in a WAV header
  Uint8List _wrapInWav(Uint8List pcmData, int sampleRate) {
    final byteRate = sampleRate * 2; // 16-bit mono
    final totalSize = 44 + pcmData.length;
    
    final wav = BytesBuilder();
    
    // RIFF header
    wav.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    wav.add(_int32ToBytes(totalSize - 8));
    wav.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"
    
    // fmt chunk
    wav.add([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    wav.add(_int32ToBytes(16)); // chunk size
    wav.add(_int16ToBytes(1)); // PCM format
    wav.add(_int16ToBytes(1)); // mono
    wav.add(_int32ToBytes(sampleRate));
    wav.add(_int32ToBytes(byteRate));
    wav.add(_int16ToBytes(2)); // block align
    wav.add(_int16ToBytes(16)); // bits per sample
    
    // data chunk
    wav.add([0x64, 0x61, 0x74, 0x61]); // "data"
    wav.add(_int32ToBytes(pcmData.length));
    wav.add(pcmData);
    
    return wav.toBytes();
  }

  Uint8List _int32ToBytes(int value) {
    return Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF;
  }

  Uint8List _int16ToBytes(int value) {
    return Uint8List(2)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF;
  }

  // ── Sound Effects ──

  /// Countdown beep: pitch increases from 3→2→1
  Future<void> playCountdownBeep(int number) async {
    final frequencies = {3: 440.0, 2: 554.0, 1: 659.0};
    final freq = frequencies[number] ?? 440.0;
    final tone = _generateTone(frequency: freq, durationMs: 100, volume: 0.4);
    await _countdownPlayer.play(BytesSource(tone));
  }

  /// GO sound: high pitched blip
  Future<void> playGo() async {
    final tone = _generateTone(frequency: 880.0, durationMs: 150, volume: 0.5);
    await _countdownPlayer.play(BytesSource(tone));
  }

  /// Good result: clean high note
  Future<void> playGoodResult() async {
    final tone = _generateTone(frequency: 784.0, durationMs: 300, volume: 0.4);
    await _resultPlayer.play(BytesSource(tone));
  }

  /// Bad result: low dull tone
  Future<void> playBadResult() async {
    final tone = _generateTone(frequency: 150.0, durationMs: 400, volume: 0.6);
    await _resultPlayer.play(BytesSource(tone));
  }

  /// Rank up: ascending 3-note melody
  Future<void> playRankUp() async {
    final note1 = _generateTone(frequency: 523.0, durationMs: 200, volume: 0.5);
    await _resultPlayer.play(BytesSource(note1));
    await Future.delayed(const Duration(milliseconds: 250));
    final note2 = _generateTone(frequency: 659.0, durationMs: 200, volume: 0.5);
    await _resultPlayer.play(BytesSource(note2));
    await Future.delayed(const Duration(milliseconds: 250));
    final note3 = _generateTone(frequency: 784.0, durationMs: 400, volume: 0.6);
    await _resultPlayer.play(BytesSource(note3));
  }

  /// Start heartbeat effect with adjustable speed
  void startHeartbeat({double speed = 1.0}) {
    _heartbeatActive = true;
    _heartbeatSpeed = speed;
    _scheduleHeartbeat();
  }

  void _scheduleHeartbeat() {
    if (!_heartbeatActive) return;
    
    final intervalMs = (800 / _heartbeatSpeed).round().clamp(200, 1500);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(Duration(milliseconds: intervalMs), () async {
      if (!_heartbeatActive) return;
      final tone = _generateTone(frequency: 80.0, durationMs: 80, volume: 0.35);
      try {
        await _heartbeatPlayer.play(BytesSource(tone));
      } catch (_) {}
      _scheduleHeartbeat();
    });
  }

  void setHeartbeatSpeed(double speed) {
    _heartbeatSpeed = speed;
  }

  void stopHeartbeat() {
    _heartbeatActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Crowd ambient murmur (simulated with noise-like tones)
  Future<void> startCrowdAmbient() async {
    // Generate a low rumble
    final tone = _generateTone(frequency: 100.0, durationMs: 3000, volume: 0.1);
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.play(BytesSource(tone));
  }

  Future<void> stopCrowdAmbient() async {
    await _ambientPlayer.stop();
  }

  void dispose() {
    stopHeartbeat();
    _countdownPlayer.dispose();
    _resultPlayer.dispose();
    _heartbeatPlayer.dispose();
    _ambientPlayer.dispose();
  }
}
