import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_history_model.dart';
import '../services/hive_service.dart';

class NotificationState {
  final int unreadCount;
  final List<NotificationHistoryItem> notifications;
  final bool isLoading;
  final int? newSyncCount;

  const NotificationState({
    this.unreadCount = 0,
    this.notifications = const [],
    this.isLoading = false,
    this.newSyncCount,
  });

  NotificationState copyWith({
    int? unreadCount,
    List<NotificationHistoryItem>? notifications,
    bool? isLoading,
    int? newSyncCount,
  }) {
    return NotificationState(
      unreadCount: unreadCount ?? this.unreadCount,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      newSyncCount: newSyncCount ?? this.newSyncCount,
    );
  }
}

class NotificationStateNotifier extends StateNotifier<NotificationState> {
  NotificationStateNotifier() : super(const NotificationState()) {
    load();
  }

  void load() {
    try {
      final history = HiveService.getNotificationHistory();
      final items = history.map((json) => NotificationHistoryItem.fromJson(json)).toList();
      final unread = items.where((n) => !n.isRead).length;
      state = NotificationState(unreadCount: unread, notifications: items);
    } catch (e) {
      state = const NotificationState();
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    // Push notifications are now delivered in real-time via OneSignal.
    // Just reload from Hive to pick up any newly saved notifications.
    load();
    state = state.copyWith(isLoading: false);
  }

  Future<void> markAsRead(String id) async {
    await HiveService.markNotificationAsRead(id);
    load();
  }

  Future<void> markAllAsRead() async {
    await HiveService.markAllNotificationsAsRead();
    load();
  }

  Future<void> deleteNotification(String id) async {
    await HiveService.deleteNotification(id);
    load();
  }

  Future<void> clearAll() async {
    await HiveService.clearNotificationHistory();
    load();
  }

  /// Reloads state from Hive without triggering a Firestore sync.
  /// Used after WorkManager background tasks add notifications.
  Future<void> refreshFromHive() async {
    load();
  }

  /// Signals that external code (e.g., WorkManager tasks) has added
  /// notifications to Hive. Reloads state to reflect the changes.
  void notifyExternalUpdate() {
    load();
  }
}

final notificationProvider = StateNotifierProvider<NotificationStateNotifier, NotificationState>((ref) {
  return NotificationStateNotifier();
});
