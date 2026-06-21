import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/sound_service.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});

final soundProvider = StateNotifierProvider<SoundNotifier, SoundState>((ref) {
  final soundService = ref.watch(soundServiceProvider);
  return SoundNotifier(soundService);
});

class SoundState {
  final bool isMuted;
  final double volume;

  const SoundState({
    this.isMuted = false,
    this.volume = 0.8,
  });

  SoundState copyWith({
    bool? isMuted,
    double? volume,
  }) {
    return SoundState(
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
    );
  }
}

class SoundNotifier extends StateNotifier<SoundState> {
  final SoundService _soundService;

  SoundNotifier(this._soundService) : super(const SoundState()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SoundState(
      isMuted: _soundService.isMuted,
      volume: _soundService.volume,
    );
  }

  void toggleMute() {
    _soundService.setMuted(!state.isMuted);
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void setVolume(double volume) {
    _soundService.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  void playButtonTap() => _soundService.playButtonTap();
  void playCorrect() => _soundService.playCorrect();
  void playWrong() => _soundService.playWrong();
  void playLevelUp() => _soundService.playLevelUp();
}