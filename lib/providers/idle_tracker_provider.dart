import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/idle_tracker_service.dart';

class IdleTrackerState {
  final bool isIdle;
  final Duration idleDuration;
  final bool showingReminder;
  final int hoursIdle;

  const IdleTrackerState({
    this.isIdle = false,
    this.idleDuration = Duration.zero,
    this.showingReminder = false,
    this.hoursIdle = 0,
  });

  IdleTrackerState copyWith({
    bool? isIdle,
    Duration? idleDuration,
    bool? showingReminder,
    int? hoursIdle,
  }) {
    return IdleTrackerState(
      isIdle: isIdle ?? this.isIdle,
      idleDuration: idleDuration ?? this.idleDuration,
      showingReminder: showingReminder ?? this.showingReminder,
      hoursIdle: hoursIdle ?? this.hoursIdle,
    );
  }
}

class IdleTrackerNotifier extends StateNotifier<IdleTrackerState> {
  IdleTrackerNotifier() : super(const IdleTrackerState());

  Future<void> checkIdleStatus() async {
    final shouldShow = await IdleTrackerService.shouldShowInAppReminder();
    final idleDuration = await IdleTrackerService.getIdleDuration();

    state = state.copyWith(
      isIdle: idleDuration.inHours >= 1,
      idleDuration: idleDuration,
      showingReminder: shouldShow,
      hoursIdle: idleDuration.inHours,
    );
  }

  Future<void> recordActivity() async {
    await IdleTrackerService.recordActivity();
    state = state.copyWith(
      isIdle: false,
      showingReminder: false,
      idleDuration: Duration.zero,
      hoursIdle: 0,
    );
  }

  Future<void> dismissReminder() async {
    await IdleTrackerService.markInAppReminderShown();
    state = state.copyWith(showingReminder: false);
  }

  Future<void> reset() async {
    await IdleTrackerService.resetReminderState();
    state = const IdleTrackerState();
  }
}

final idleTrackerProvider =
    StateNotifierProvider<IdleTrackerNotifier, IdleTrackerState>((ref) {
  return IdleTrackerNotifier();
});
