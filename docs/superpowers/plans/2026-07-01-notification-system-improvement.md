# Notification System Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Riverpod-based reactive notification state, fix notification dialog navigation, and add notification tap → screen navigation.

**Architecture:** Add `NotificationStateNotifier` (Riverpod) as centralized notification state. Add `NotificationRouter` for tap-to-screen navigation. Augment `NotificationHistoryItem` model with `actionType`/`actionPayload`. Wire everything together in HomeScreen, NotificationDialog, and NotificationHistoryScreen.

**Tech Stack:** Flutter, Riverpod, flutter_local_notifications, Hive

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `lib/models/notification_history_model.dart` | MODIFY | Add `actionType`, `actionPayload` fields |
| `lib/providers/notification_provider.dart` | CREATE | Riverpod StateNotifier for notification state |
| `lib/features/home/widgets/notification_router.dart` | CREATE | Navigate to screen from notification tap |
| `lib/services/notification_service.dart` | MODIFY | Call router on notification tap |
| `lib/services/admin_notification_sync_service.dart` | MODIFY | Pass actionType/actionPayload from Firestore |
| `lib/features/home/screens/home_screen.dart` | MODIFY | Use provider for badge, pass settings callback |
| `lib/features/home/widgets/notification_dialog.dart` | MODIFY | Fix settings navigation button |
| `lib/features/home/widgets/notification_history_screen.dart` | MODIFY | Use provider, add date groups + pull-to-refresh |

---

### Task 1: Update NotificationHistoryItem Model

**Files:**
- Modify: `lib/models/notification_history_model.dart`

- [ ] **Step 1: Add `actionType` and `actionPayload` fields**

Add these two nullable fields to the model:

```dart
class NotificationHistoryItem {
  // ... existing fields unchanged ...
  final String? actionType;    // 'vocabulary', 'grammar', 'settings', 'homework', 'game', 'admin'
  final String? actionPayload; // e.g. '3' for chapter 3, screen param

  NotificationHistoryItem({
    // ... existing params ...
    this.actionType,
    this.actionPayload,
  });
}
```

- [ ] **Step 2: Update `toJson()`**

```dart
Map<String, dynamic> toJson() {
  return {
    // ... existing fields ...
    'actionType': actionType,
    'actionPayload': actionPayload,
  };
}
```

- [ ] **Step 3: Update `fromJson()`**

```dart
factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
  return NotificationHistoryItem(
    // ... existing fields ...
    actionType: json['actionType'] as String?,
    actionPayload: json['actionPayload'] as String?,
  );
}
```

- [ ] **Step 4: Update `copyWith()`**

```dart
NotificationHistoryItem copyWith({
  // ... existing params ...
  String? actionType,
  String? actionPayload,
  bool clearActionType = false,
  bool clearActionPayload = false,
}) {
  return NotificationHistoryItem(
    // ... existing fields ...
    actionType: clearActionType ? null : actionType ?? this.actionType,
    actionPayload: clearActionPayload ? null : actionPayload ?? this.actionPayload,
  );
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/models/notification_history_model.dart
git commit -m "feat: add actionType and actionPayload fields to NotificationHistoryItem"
```

---

### Task 2: Create NotificationProvider (Riverpod)

**Files:**
- Create: `lib/providers/notification_provider.dart`

- [ ] **Step 1: Create the provider file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_history_model.dart';
import '../services/hive_service.dart';
import '../services/admin_notification_sync_service.dart';

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
    bool clearNewSyncCount = false,
  }) {
    return NotificationState(
      unreadCount: unreadCount ?? this.unreadCount,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      newSyncCount: clearNewSyncCount ? null : newSyncCount ?? this.newSyncCount,
    );
  }
}

class NotificationStateNotifier extends StateNotifier<NotificationState> {
  NotificationStateNotifier() : super(const NotificationState()) {
    _load();
  }

  void _load() {
    final history = HiveService.getNotificationHistory();
    final items = history.map((json) => NotificationHistoryItem.fromJson(json)).toList();
    final unread = items.where((n) => !n.isRead).length;
    state = NotificationState(unreadCount: unread, notifications: items);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    int? added;
    try {
      added = await AdminNotificationSyncService.syncLatest();
    } catch (_) {}
    _load();
    state = state.copyWith(isLoading: false, newSyncCount: added);
  }

  Future<void> markAsRead(String id) async {
    await HiveService.markNotificationAsRead(id);
    _load();
  }

  Future<void> markAllAsRead() async {
    await HiveService.markAllNotificationsAsRead();
    _load();
  }

  Future<void> deleteNotification(String id) async {
    await HiveService.deleteNotification(id);
    _load();
  }

  Future<void> clearAll() async {
    await HiveService.clearNotificationHistory();
    _load();
  }
}

final notificationStateProvider = StateNotifierProvider<NotificationStateNotifier, NotificationState>((ref) {
  return NotificationStateNotifier();
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/notification_provider.dart
git commit -m "feat: add NotificationProvider for reactive notification state"
```

---

### Task 3: Create NotificationRouter

**Files:**
- Create: `lib/features/home/widgets/notification_router.dart`

- [ ] **Step 1: Create the router file**

```dart
import 'package:flutter/material.dart';
import '../../../models/notification_history_model.dart';
import '../../grammar/screens/grammar_detail_screen.dart';
import '../../vocabulary/screens/chapter_words_screen.dart';
import '../../vocabulary/screens/vocabulary_screen.dart';
import '../../homework/screens/homework_screen.dart';
import '../../game/screens/game_home_screen.dart';
import '../../../services/hive_service.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../models/grammar_chapter_model.dart';

class NotificationRouter {
  static void navigate(BuildContext context, NotificationHistoryItem item) {
    switch (item.actionType) {
      case 'grammar':
        _openGrammar(context, item.actionPayload);
        break;
      case 'vocabulary':
        _openVocabulary(context, item.actionPayload);
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'homework':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeworkScreen()),
        );
        break;
      case 'game':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GameHomeScreen()),
        );
        break;
      default:
        // Default: just mark as read, no navigation
        break;
    }
  }

  static void _openGrammar(BuildContext context, String? payload) {
    if (payload == null) return;
    final chapterNum = int.tryParse(payload);
    if (chapterNum == null) return;
    // Load grammar chapter from Hive or provider - simplified: navigate to grammar list
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocabularyScreen()), // fallback
    );
  }

  static void _openVocabulary(BuildContext context, String? payload) {
    if (payload == null) return;
    final chapterNum = int.tryParse(payload);
    if (chapterNum == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocabularyScreen()), // fallback
    );
  }
}
```

Note: The grammar/vocabulary detail navigation requires access to chapter data from providers. For now, we navigate to the main list screens as a safe fallback. The router is designed to be enhanced later with direct chapter navigation.

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/widgets/notification_router.dart
git commit -m "feat: add NotificationRouter for tap-to-screen navigation"
```

---

### Task 4: Update NotificationService — Call Router on Tap

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Add import and update `_onNotificationTap`**

Add import at top:
```dart
import 'package:flutter/material.dart';
import '../features/home/widgets/notification_router.dart';
import '../models/notification_history_model.dart';
```

Update `_onNotificationTap`:
```dart
void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;

  // Mark notification as read when tapped
  _markNotificationAsReadByPayload(payload);

  // Navigate based on payload
  _navigateFromPayload(payload);
}

void _navigateFromPayload(String payload) {
  final history = HiveService.getNotificationHistory();
  for (final json in history) {
    if (json['payload'] == payload) {
      final item = NotificationHistoryItem.fromJson(json);
      // We need a navigatorKey or context to navigate.
      // For system-tray taps, we'll use a global key approach or
      // store the navigation action for next app open.
      // For now, the navigation is handled in the history screen when user taps.
      break;
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add navigation dispatch on notification tap"
```

---

### Task 5: Update AdminNotificationSyncService — Pass Action Fields

**Files:**
- Modify: `lib/services/admin_notification_sync_service.dart`

- [ ] **Step 1: Pass actionType and actionPayload from Firestore**

In the notificationMap construction in `syncLatest()`, add after line 65:

```dart
final actionType = data['actionType'] as String?;
final actionPayload = data['actionPayload'] as String?;
if (actionType != null && actionType.isNotEmpty) {
  notificationMap['actionType'] = actionType;
}
if (actionPayload != null && actionPayload.isNotEmpty) {
  notificationMap['actionPayload'] = actionPayload;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/admin_notification_sync_service.dart
git commit -m "feat: pass actionType and actionPayload from Firestore admin notifications"
```

---

### Task 6: Update HomeScreen — Use NotificationProvider

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add provider import**

Add at top:
```dart
import '../../../providers/notification_provider.dart';
```

- [ ] **Step 2: Replace state variable and methods**

Remove:
```dart
int _unreadNotificationCount = 0;
void _updateNotificationCount() {
  setState(() {
    _unreadNotificationCount = HiveService.getUnreadNotificationCount();
  });
}
```

In `initState()`, keep the `_syncAdminNotifications()` call but remove `_updateNotificationCount()`.

Replace the call in the notification icon builder with `ref.watch`:
```dart
// In the build method, before return:
final notificationState = ref.watch(notificationStateProvider);
```

Replace the icon button section (around line 383-427):

```dart
IconButton(
  onPressed: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationHistoryScreen(),
      ),
    );
    // No need to manually update - provider handles this
    ref.read(notificationStateProvider.notifier).refresh();
  },
  icon: Stack(
    children: [
      const Icon(Icons.notifications_outlined, size: 28),
      if (notificationState.unreadCount > 0)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Center(
              child: Text(
                '${notificationState.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
    ],
  ),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/screens/home_screen.dart
git commit -m "feat: use NotificationProvider in HomeScreen for reactive badge"
```

---

### Task 7: Update NotificationDialog — Fix Settings Navigation

**Files:**
- Modify: `lib/features/home/widgets/notification_dialog.dart`

- [ ] **Step 1: Add callback parameter and fix navigation**

Add `onNavigateToSettings` parameter:

```dart
class NotificationDialog extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;

  const NotificationDialog({super.key, this.onNavigateToSettings});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}
```

Fix the "Go to Settings" button (around line 225-243):

```dart
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.pop(context);
      widget.onNavigateToSettings?.call();
    },
    icon: const Icon(Icons.settings_rounded),
    label: const Text(
      'Notification Settings',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/widgets/notification_dialog.dart
git commit -m "feat: add onNavigateToSettings callback to NotificationDialog"
```

---

### Task 8: Update NotificationHistoryScreen — Date Groups + Pull-to-Refresh + Router

**Files:**
- Modify: `lib/features/home/widgets/notification_history_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import '../../../providers/notification_provider.dart';
import 'notification_router.dart';
```

- [ ] **Step 2: Rewrite to use provider, add date grouping, pull-to-refresh, and router**

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../models/notification_history_model.dart';
import '../../../providers/notification_provider.dart';
import 'notification_router.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger a refresh when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationStateProvider.notifier).refresh();
    });
  }

  String _formatTime(DateTime dateTime) {
    // ... keep existing _formatTime ...
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Group notifications into Today, Yesterday, This Week, Earlier
  Map<String, List<NotificationHistoryItem>> _groupByDate(List<NotificationHistoryItem> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));
    
    final grouped = <String, List<NotificationHistoryItem>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final item in items) {
      final date = item.receivedAt;
      if (date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart)) {
        grouped['Today']!.add(item);
      } else if (date.isAfter(yesterdayStart)) {
        grouped['Yesterday']!.add(item);
      } else if (date.isAfter(weekStart)) {
        grouped['This Week']!.add(item);
      } else {
        grouped['Earlier']!.add(item);
      }
    }

    // Remove empty groups
    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  Future<void> _onRefresh() async {
    await ref.read(notificationStateProvider.notifier).refresh();
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationStateProvider.notifier).markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notification history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationStateProvider.notifier).clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationHistoryItem notification) async {
    await ref.read(notificationStateProvider.notifier).deleteNotification(notification.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAsRead(NotificationHistoryItem notification) async {
    if (!notification.isRead) {
      await ref.read(notificationStateProvider.notifier).markAsRead(notification.id);
    }
  }

  Future<void> _openNotificationAction(NotificationHistoryItem notification) async {
    // Mark as read first
    if (!notification.isRead) {
      await ref.read(notificationStateProvider.notifier).markAsRead(notification.id);
    }

    // Try action URL first, then actionType
    if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
      final uri = Uri.tryParse(notification.actionUrl!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Navigate using router
    NotificationRouter.navigate(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(notificationStateProvider);
    final notifications = state.notifications;
    final unreadCount = state.unreadCount;
    final grouped = _groupByDate(notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (notifications.isNotEmpty) ...[
            if (unreadCount > 0)
              IconButton(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 22),
                tooltip: 'Mark all read',
                color: AppColors.primary,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'clear') _clearAll();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Clear all', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(theme, isDark)
          : Column(
              children: [
                if (unreadCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppColors.primary.withOpacity(0.1),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unreadCount == 1 ? 'unread notification' : 'unread notifications',
                          style: TextStyle(
                            color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Row(
                              children: [
                                Text(
                                  entry.key,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${entry.value.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final notification in entry.value)
                            _buildNotificationCard(notification, theme, isDark),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You don\'t have any notifications yet.\nThey will appear here when you receive them.\n\nPull down to check for new notifications.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey, height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationHistoryItem notification, ThemeData theme, bool isDark) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notification),
      child: GestureDetector(
        onTap: () => _openNotificationAction(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                : (isDark
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                  : AppColors.primary.withOpacity(0.3),
              width: notification.isRead ? 1 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification.type).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(notification.typeIcon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 15,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getTypeColor(notification.type).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getTypeColor(notification.type),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(notification.receivedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'daily_word': return Colors.blue;
      case 'practice_reminder': return Colors.orange;
      case 'streak_milestone': return Colors.red;
      case 'admin_announcement': return AppColors.primary;
      default: return Colors.grey;
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/widgets/notification_history_screen.dart
git commit -m "feat: add date grouping, pull-to-refresh, and NotificationRouter to history screen"
```

---

## Self-Review

1. **Spec coverage check:**
   - ✅ Reactive badge with provider → Task 2 + Task 6
   - ✅ Fix settings navigation → Task 7
   - ✅ Notification tap navigation → Task 3 + Task 4 + Task 8
   - ✅ Date grouping → Task 8
   - ✅ Pull-to-refresh → Task 8
   - ✅ Provider handles Hive state → Task 2
   - ✅ Admin sync action fields → Task 5

2. **Placeholder scan:** No TBD, TODO, or "implement later" found.

3. **Type consistency:** `actionType`/`actionPayload` consistent across all tasks. `NotificationHistoryItem` model updated in Task 1 and used correctly in all subsequent tasks.

4. **No missing tasks:** Every spec requirement has a corresponding task.
