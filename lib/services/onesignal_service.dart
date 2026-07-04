import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'hive_service.dart';

/// Service that wraps the OneSignal SDK for push notification handling.
///
/// Responsibilities:
/// - Initialize OneSignal with the App ID
/// - Request notification permissions
/// - Listen for incoming push notifications and save them to Hive history
/// - Listen for notification taps and route appropriately
///
/// OneSignal App ID is loaded from Firestore config (config/app_settings →
/// onesignal.appId) so it can be updated remotely without an app release.
class OneSignalService {
  static final OneSignalService _instance = OneSignalService._();
  factory OneSignalService() => _instance;
  OneSignalService._();

  bool _initialized = false;
  String _appId = '';
  String? _playerId;

  /// The OneSignal App ID used for initialization.
  String get appId => _appId;

  /// The OneSignal player (subscription) ID for this device.
  String? get playerId => _playerId;

  bool get isInitialized => _initialized;

  /// Initializes OneSignal with the given [appId].
  ///
  /// Sets up notification click and receive listeners, requests permissions,
  /// and captures the push subscription ID for targeted messaging.
  Future<void> initialize(String appId) async {
    if (_initialized) return;

    _appId = appId;

    if (_appId.isEmpty || _appId == 'YOUR_ONESIGNAL_APP_ID') {
      debugPrint('OneSignal: Skipping init — no valid App ID configured.');
      return;
    }

    try {
      // Log level — mute in production builds
      OneSignal.Debug.setLogLevel(
        kReleaseMode ? OSLogLevel.warn : OSLogLevel.verbose,
      );

      OneSignal.initialize(_appId);

      // ── Foreground notification handler ──
      // OneSignal v5: if you call preventDefault(), the notification is HIDDEN.
      // We want to SAVE to history AND show the notification, so we do NOT
      // call preventDefault() — the OS shows it automatically after the listener.
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final notif = event.notification;
        _saveToHistory(notif);
        // Do NOT call preventDefault() — we want the notification to display
        // as a heads-up banner. The notification is delivered to system tray
        // even when the app is closed (via native Android OneSignal service).
      });

      // ── Notification tap handler ──
      OneSignal.Notifications.addClickListener((event) {
        final notif = event.notification;
        // Mark as read and navigate
        _handleNotificationOpened(notif);
      });

      // Request permission (iOS shows native prompt, Android 13+ shows prompt)
      await OneSignal.Notifications.requestPermission(true);

      // Capture the push subscription ID for potential server-side targeting
      final subscription = OneSignal.User.pushSubscription;
      _playerId = subscription.id;
      subscription.addObserver((state) {
        _playerId = state.current.id;
      });

      _initialized = true;
      debugPrint('OneSignal: initialized successfully (playerId: $_playerId)');
    } catch (e) {
      debugPrint('OneSignal: initialization failed — $e');
    }
  }

  /// Handles a notification that was tapped by the user.
  ///
  /// Marks it as read in Hive history and logs navigation intent.
  void _handleNotificationOpened(OSNotification notification) {
    final additionalData = notification.additionalData ?? {};
    final notifId = additionalData['notification_id'] as String?;

    if (notifId != null) {
      HiveService.markNotificationAsRead(notifId);
    }

    // Log navigation intent for the notification router
    final actionType = additionalData['actionType'] as String?;
    final actionPayload = additionalData['actionPayload'] as String?;
    debugPrint(
      'OneSignal: notification tapped — actionType: $actionType, '
      'actionPayload: $actionPayload',
    );

    // Navigation from system tray is best-effort without a global navigator key.
    // In-app navigation is handled when the user opens NotificationHistoryScreen.
  }

  /// Saves a received OSNotification to the local Hive history.
  void _saveToHistory(OSNotification notification) {
    try {
      final additionalData = notification.additionalData ?? {};
      final title = notification.title ?? '';
      final body = notification.body ?? '';

      if (title.isEmpty && body.isEmpty) return;

      final notifId = additionalData['notification_id'] as String? ??
          'os_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

      final notificationMap = <String, dynamic>{
        'id': notifId,
        'title': title,
        'body': body,
        'type': additionalData['type'] as String? ?? 'push',
        'receivedAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'payload': additionalData['payload'] as String?,
      };

      // Forward optional fields if present
      final actionUrl = additionalData['actionUrl'] as String?;
      if (actionUrl != null && actionUrl.isNotEmpty) {
        notificationMap['actionUrl'] = actionUrl;
      }
      final actionType = additionalData['actionType'] as String?;
      if (actionType != null && actionType.isNotEmpty) {
        notificationMap['actionType'] = actionType;
      }
      final actionPayload = additionalData['actionPayload'] as String?;
      if (actionPayload != null && actionPayload.isNotEmpty) {
        notificationMap['actionPayload'] = actionPayload;
      }

      HiveService.saveNotificationToHistoryIfNew(notificationMap);
    } catch (e) {
      debugPrint('OneSignal: failed to save notification to history — $e');
    }
  }
}
