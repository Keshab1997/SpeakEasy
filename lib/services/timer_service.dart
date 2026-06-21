import 'dart:async';
import 'package:flutter/foundation.dart';

enum TimerState { idle, running, paused, finished }

class TimerService {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  TimerState _state = TimerState.idle;
  void Function(int remaining)? _onTick;
  VoidCallback? _onFinish;

  TimerState get state => _state;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  double get progress => _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0.0;
  bool get isRunning => _state == TimerState.running;
  bool get isPaused => _state == TimerState.paused;
  bool get isFinished => _state == TimerState.finished;

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void start({
    required int seconds,
    void Function(int remaining)? onTick,
    VoidCallback? onFinish,
  }) {
    dispose();

    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _state = TimerState.running;
    _onTick = onTick;
    _onFinish = onFinish;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      _onTick?.call(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        _state = TimerState.finished;
        _timer?.cancel();
        _timer = null;
        _onFinish?.call();
      }
    });
  }

  void pause() {
    if (_state != TimerState.running) return;
    _state = TimerState.paused;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_state != TimerState.paused) return;
    if (_remainingSeconds <= 0) return;

    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      _onTick?.call(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        _state = TimerState.finished;
        _timer?.cancel();
        _timer = null;
        _onFinish?.call();
      }
    });
  }

  void addTime(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
  }

  void subtractTime(int seconds) {
    _remainingSeconds = (_remainingSeconds - seconds).clamp(0, _totalSeconds);
  }

  void reset() {
    dispose();
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _state = TimerState.idle;
    _onTick = null;
    _onFinish = null;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Preset Timers ──

  void startQuickGame({VoidCallback? onFinish}) {
    start(seconds: 30, onFinish: onFinish);
  }

  void startStandardGame({VoidCallback? onFinish}) {
    start(seconds: 60, onFinish: onFinish);
  }

  void startChallengeGame({VoidCallback? onFinish}) {
    start(seconds: 120, onFinish: onFinish);
  }

  void startPerQuestionTimer({
    required int secondsPerQuestion,
    required int questionCount,
    VoidCallback? onFinish,
  }) {
    start(seconds: secondsPerQuestion * questionCount, onFinish: onFinish);
  }
}