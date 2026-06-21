import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/timer_service.dart';

// ── Timer State ──

class TimerState {
  final int remainingSeconds;
  final int totalSeconds;
  final TimerStateStatus status;

  const TimerState({
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.status = TimerStateStatus.idle,
  });

  TimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    TimerStateStatus? status,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      status: status ?? this.status,
    );
  }

  double get progress {
    if (totalSeconds <= 0) return 0.0;
    return remainingSeconds / totalSeconds;
  }

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isRunning => status == TimerStateStatus.running;
  bool get isPaused => status == TimerStateStatus.paused;
  bool get isFinished => status == TimerStateStatus.finished;
  bool get isIdle => status == TimerStateStatus.idle;
}

enum TimerStateStatus { idle, running, paused, finished }

class TimerNotifier extends StateNotifier<TimerState> {
  final TimerService _timerService;

  TimerNotifier(this._timerService) : super(const TimerState());

  void startTimer({required int seconds}) {
    _timerService.start(
      seconds: seconds,
      onTick: (remaining) {
        state = state.copyWith(
          remainingSeconds: remaining,
          status: TimerStateStatus.running,
        );
      },
      onFinish: () {
        state = state.copyWith(
          remainingSeconds: 0,
          status: TimerStateStatus.finished,
        );
      },
    );

    state = state.copyWith(
      remainingSeconds: seconds,
      totalSeconds: seconds,
      status: TimerStateStatus.running,
    );
  }

  void pauseTimer() {
    _timerService.pause();
    state = state.copyWith(status: TimerStateStatus.paused);
  }

  void resumeTimer() {
    _timerService.resume();
    state = state.copyWith(status: TimerStateStatus.running);
  }

  void addTime(int seconds) {
    _timerService.addTime(seconds);
    state = state.copyWith(
      remainingSeconds: _timerService.remainingSeconds,
      totalSeconds: _timerService.totalSeconds,
    );
  }

  void subtractTime(int seconds) {
    _timerService.subtractTime(seconds);
    state = state.copyWith(
      remainingSeconds: _timerService.remainingSeconds,
    );
  }

  void resetTimer() {
    _timerService.reset();
    state = const TimerState();
  }

  void startQuickGame() {
    startTimer(seconds: 30);
  }

  void startStandardGame() {
    startTimer(seconds: 60);
  }

  void startChallengeGame() {
    startTimer(seconds: 120);
  }

  @override
  void dispose() {
    _timerService.dispose();
    super.dispose();
  }
}

final timerServiceProvider = Provider<TimerService>((ref) {
  return TimerService();
});

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  final timerService = ref.watch(timerServiceProvider);
  return TimerNotifier(timerService);
});