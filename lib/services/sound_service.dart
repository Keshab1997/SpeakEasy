import 'package:audioplayers/audioplayers.dart';
import 'hive_service.dart';

enum GameSoundEffect {
  correct,
  wrong,
  levelUp,
  achievement,
  countdown,
  gameOver,
  tick,
  buttonTap,
  coinCollect,
  streakBonus,
  notificationReminder,
  notificationCharacter,
}

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  double _volume = 1.0;

  SoundService() {
    // Restore previously saved sound preferences so the setting survives
    // app restarts instead of resetting to "on" every launch.
    _muted = HiveService.isSoundMuted();
    _volume = HiveService.getSoundVolume();
    _player.setVolume(_muted ? 0.0 : _volume);
  }

  bool get isMuted => _muted;
  double get volume => _volume;

  void setMuted(bool value) {
    _muted = value;
    HiveService.setSoundMuted(value);
    _player.setVolume(_muted ? 0.0 : _volume);
  }

  void toggleMute() {
    setMuted(!_muted);
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    HiveService.setSoundVolume(_volume);
    _player.setVolume(_muted ? 0.0 : _volume);
  }

  Future<void> playSound(GameSoundEffect effect) async {
    if (_muted) return;

    final assetPath = _getAssetPath(effect);
    if (assetPath == null) return;

    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Sound file not available — silently continue
    }
  }

  Future<void> playCorrect() => playSound(GameSoundEffect.correct);
  Future<void> playWrong() => playSound(GameSoundEffect.wrong);
  Future<void> playLevelUp() => playSound(GameSoundEffect.levelUp);
  Future<void> playAchievement() => playSound(GameSoundEffect.achievement);
  Future<void> playGameOver() => playSound(GameSoundEffect.gameOver);
  Future<void> playButtonTap() => playSound(GameSoundEffect.buttonTap);
  Future<void> playCoinCollect() => playSound(GameSoundEffect.coinCollect);
  Future<void> playStreakBonus() => playSound(GameSoundEffect.streakBonus);

  Future<void> playNotificationReminder() =>
      playSound(GameSoundEffect.notificationReminder);

  Future<void> playNotificationCharacter() =>
      playSound(GameSoundEffect.notificationCharacter);

  String? _getAssetPath(GameSoundEffect effect) {
    switch (effect) {
      case GameSoundEffect.correct:
        return 'audio/game_correct.mp3';
      case GameSoundEffect.wrong:
        return 'audio/game_wrong.mp3';
      case GameSoundEffect.levelUp:
        return 'audio/game_level_up.mp3';
      case GameSoundEffect.achievement:
        return 'audio/game_achievement.mp3';
      case GameSoundEffect.countdown:
        return 'audio/game_countdown.mp3';
      case GameSoundEffect.gameOver:
        return 'audio/game_over.mp3';
      case GameSoundEffect.tick:
        return 'audio/game_tick.mp3';
      case GameSoundEffect.buttonTap:
        return 'audio/game_button_tap.mp3';
      case GameSoundEffect.coinCollect:
        return 'audio/game_coin_collect.mp3';
      case GameSoundEffect.streakBonus:
        return 'audio/game_streak_bonus.mp3';
      case GameSoundEffect.notificationReminder:
        return 'audio/notification_reminder.mp3';
      case GameSoundEffect.notificationCharacter:
        return 'audio/notification_character.mp3';
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}