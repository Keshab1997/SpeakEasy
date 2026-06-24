import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _muted = false;

  bool get isMuted => _muted;

  void setMuted(bool value) {
    _muted = value;
    if (value) _tts.stop();
  }

  void toggleMute() => setMuted(!_muted);

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (_muted) return;
    if (!_isInitialized) await initialize();
    await _tts.speak(text);
  }

  /// Speak a Bangla (Bengali) word using bn-BD locale
  Future<void> speakBangla(String text) async {
    if (_muted) return;
    if (!_isInitialized) await initialize();
    try {
      await _tts.setLanguage('bn-BD');
      await _tts.speak(text);
      await _tts.setLanguage('en-US'); // reset to English
    } catch (_) {
      // If Bangla TTS fails, try Hindi or reset to English
      try {
        await _tts.setLanguage('hi-IN');
        await _tts.speak(text);
      } catch (_) {}
      await _tts.setLanguage('en-US');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
