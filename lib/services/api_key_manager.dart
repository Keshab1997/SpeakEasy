import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/admin_api_key.dart';
import '../models/admin_key_group.dart';
import '../models/api_error_log.dart';
import 'hive_service.dart';
import 'key_health_checker.dart' as key_health;
import 'key_pool_selector.dart';

class ApiKeyManager {
  static final ApiKeyManager instance = ApiKeyManager._();
  ApiKeyManager._();

  // ── State ──
  List<AdminApiKey> _keyPool = [];
  Map<String, AdminKeyGroup> _groups = {};
  final List<KeyCooldown> _cooldownList = [];

  /// Consecutive 401/403 failures per key. Reaching [_consecutiveAuthFailureLimit]
  /// auto-deactivates the key globally (see [_deactivateKey]).
  final Map<String, int> _consecutiveAuthFailures = {};
  DateTime? _lastLogCleanup;
  final Completer<void> _readyCompleter = Completer<void>();
  int _currentIndex = 0;
  bool _allKeysFailedNotified = false;
  DateTime? _lastAllKeysFailedNotification;
  Timer? _notificationCooldownTimer;
  Timer? _batchTimer;
  Timer? _healthCheckTimer;
  bool _healthCheckInProgress = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupSub;

  // Error batching
  final List<ApiErrorLog> _errorQueue = [];
  bool _initialized = false;

  // Constants
  static const Duration _notificationDebounce = Duration(minutes: 5);
  static const int _batchSize = 20;
  static const Duration _batchInterval = Duration(seconds: 30);

  /// Hard cap on the in-memory error queue so a prolonged Firestore outage
  /// can't grow it without bound (oldest entries are dropped first).
  static const int _maxErrorQueue = 500;

  /// Consecutive 401/403 failures after which a key is auto-deactivated.
  static const int _consecutiveAuthFailureLimit = 3;

  /// Error-log cleanup runs at most this often. Free-plan fallback for
  /// Firestore TTL, which requires billing.
  static const Duration _logCleanupInterval = Duration(hours: 1);
  static const Duration _logRetention = Duration(days: 30);

  /// How often the proactive health check pings the primary key.
  static const Duration _healthCheckInterval = Duration(minutes: 30);

  /// Skip re-reporting a key the health check already flagged recently (all
  /// devices ping, so this prevents duplicate error logs per key).
  static const Duration _healthCheckDedup = Duration(hours: 2);

  // ── Public API ──

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _loadFromCache();
    _loadCooldownsFromCache();
    _startFirestoreListener();
    _startGroupListener();
    _batchTimer = Timer.periodic(_batchInterval, (_) => _flushErrorQueue());
    _healthCheckTimer =
        Timer.periodic(_healthCheckInterval, (_) => _runHealthCheck());
    _cleanupExpiredErrorLogs();
    debugPrint('[ApiKeyManager] initialized');
  }

  /// Returns the next healthy key from the highest-priority enabled group
  /// (round-robin within that group). Slower groups are used only as a
  /// fallback when every key of the preferred group is on cooldown, so the
  /// "fast" group carries the load while the rest wait in reserve.
  AdminApiKey? getNextKey() {
    final result = _selector().select(_currentIndex);
    _currentIndex = result.$2;
    return result.$1;
  }

  /// Returns the first healthy key WITHOUT consuming it (for model fetching etc).
  /// Returns null if all keys are exhausted or none configured.
  AdminApiKey? peekFirstKey() {
    final healthy = _getHealthyKeys();
    if (healthy.isEmpty) return null;
    return healthy.first;
  }

  /// Report a successful API call.
  void reportSuccess(AdminApiKey key) {
    _consecutiveAuthFailures.remove(key.id);
    _incrementUsage(key.id);
  }

  /// Report a failed API call.
  void reportFailure(
      AdminApiKey key, int statusCode, String feature, String userId) {
    final errorType = _classifyError(statusCode);
    final duration = _getCooldownDuration(statusCode, key.provider);
    // Whether another healthy key exists to retry with — checked before this
    // key goes on cooldown. Retry success is unknown at this point.
    final canRetry = _getHealthyKeys().any((k) => k.id != key.id);

    _cooldownList.add(KeyCooldown(
      keyId: key.id,
      until: DateTime.now().add(duration),
    ));
    _cooldownList.removeWhere((c) => c.until.isBefore(DateTime.now()));
    _saveCooldownsToCache();

    _enqueueError(ApiErrorLog(
      keyId: key.id,
      keyName: key.name,
      userId: userId,
      feature: feature,
      errorType: errorType,
      statusCode: statusCode,
      message: _errorMessage(statusCode),
      retried: canRetry,
      retrySuccess: false,
      timestamp: DateTime.now(),
    ));

    // Push error stats to Firestore so the admin screen shows live error counts.
    unawaited(_updateKeyStats(key.id, lastErrorAt: DateTime.now()));

    // Repeated auth failures mean the key is dead: deactivate it globally via
    // Firestore so every device stops using it, instead of relying only on the
    // device-local cooldown.
    if (errorType == 'auth_error') {
      _recordAuthFailure(key);
    }

    if (_getHealthyKeys().isEmpty) {
      _handleAllKeysFailed();
    }
  }

  /// Increments the consecutive auth-failure counter for a key and deactivates
  /// it globally once the limit is reached. Shared by [reportFailure] and the
  /// periodic health check.
  void _recordAuthFailure(AdminApiKey key) {
    final failures = (_consecutiveAuthFailures[key.id] ?? 0) + 1;
    _consecutiveAuthFailures[key.id] = failures;
    if (failures >= _consecutiveAuthFailureLimit) {
      _deactivateKey(key.id);
    }
  }

  /// Proactively pings the primary healthy key so a dead (unused) key is
  /// caught before users hit it — the failure-time auto-deactivate only fires
  /// on real calls. Only auth errors (401/403) act: rate limits, server errors
  /// and network failures are transient and already handled by the normal
  /// failure path.
  void _runHealthCheck() {
    if (_healthCheckInProgress) return;
    final key = peekFirstKey();
    if (key == null) return;
    _healthCheckInProgress = true;
    unawaited(() async {
      try {
        final status = await key_health.pingKeyStatus(
          provider: key.provider,
          baseUrl: key.baseUrl,
          apiKey: key.key,
          model: key.model,
        );
        debugPrint('[ApiKeyManager] Health check ${key.name}: HTTP $status');
        if (status == 200) {
          _consecutiveAuthFailures.remove(key.id);
        } else if (status == 401 || status == 403) {
          // Every device pings, so dedupe by the key's last reported error.
          final lastError = key.lastErrorAt;
          if (lastError == null ||
              DateTime.now().difference(lastError) > _healthCheckDedup) {
            reportFailure(key, status, 'health_check', '');
          }
        }
        // status 0 (network) and everything else: transient — don't act.
      } catch (e) {
        debugPrint('[ApiKeyManager] Health check error: $e');
      } finally {
        _healthCheckInProgress = false;
      }
    }());
  }

  /// Returns health stats for all keys (for admin dashboard).
  List<Map<String, dynamic>> getKeyHealth() {
    return _keyPool.map((k) {
      final isOnCooldown = _cooldownList.any((c) => c.keyId == k.id);
      return {
        'id': k.id,
        'name': k.name,
        'isActive': k.isActive,
        'isOnCooldown': isOnCooldown,
        'usageCount': k.usageCount,
        'errorCount': k.errorCount,
        'lastErrorAt': k.lastErrorAt?.toIso8601String(),
        'lastUsedAt': k.lastUsedAt?.toIso8601String(),
      };
    }).toList();
  }

  void refreshKeys() {
    _loadFromCache();
  }

  /// True once the key pool has been loaded (from cache or Firestore) at least
  /// once. Lets callers distinguish "still loading" from "no keys configured".
  bool get isReady => _readyCompleter.isCompleted;

  /// Waits until the admin key pool has been loaded, so a call made immediately
  /// after app start doesn't race the async Firestore listener. Falls back
  /// (returns) after [timeout] so callers surface their own empty-pool error.
  Future<void> ensureReady() async {
    if (_readyCompleter.isCompleted) return;
    await _readyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
  }

  void dispose() {
    _firestoreSub?.cancel();
    _groupSub?.cancel();
    _batchTimer?.cancel();
    _healthCheckTimer?.cancel();
    _notificationCooldownTimer?.cancel();
  }

  // ── Private ──

  void _startFirestoreListener() {
    _firestoreSub = FirebaseFirestore.instance
        .collection('admin_api_keys')
        .snapshots()
        .listen((snapshot) {
      _keyPool = snapshot.docs
          .map((doc) => AdminApiKey.fromMap(doc.data(), doc.id))
          .where((k) => k.isActive)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      _saveToCache();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      debugPrint(
          '[ApiKeyManager] Keys updated: ${_keyPool.length} active keys');
    }, onError: (e) {
      debugPrint('[ApiKeyManager] Firestore listener error: $e');
    });
  }

  void _loadFromCache() {
    try {
      final cached = HiveService.getCachedAdminKeys();
      if (cached.isNotEmpty) {
        _keyPool = cached;
        if (!_readyCompleter.isCompleted) _readyCompleter.complete();
        debugPrint('[ApiKeyManager] Loaded ${_keyPool.length} keys from cache');
      }
    } catch (e) {
      debugPrint('[ApiKeyManager] Cache load error: $e');
    }
  }

  void _saveToCache() {
    try {
      HiveService.saveCachedAdminKeys(_keyPool);
    } catch (e) {
      debugPrint('[ApiKeyManager] Cache save error: $e');
    }
  }

  void _loadCooldownsFromCache() {
    try {
      final cached = HiveService.getCachedAdminKeyCooldowns();
      if (cached.isEmpty) return;
      final now = DateTime.now();
      _cooldownList.clear();
      for (final c in cached) {
        final until = DateTime.tryParse(c['until'] as String? ?? '');
        if (until != null && until.isAfter(now)) {
          _cooldownList
              .add(KeyCooldown(keyId: c['keyId'] as String, until: until));
        }
      }
      debugPrint(
          '[ApiKeyManager] Loaded ${_cooldownList.length} cooldowns from cache');
    } catch (e) {
      debugPrint('[ApiKeyManager] Cooldown cache load error: $e');
    }
  }

  void _saveCooldownsToCache() {
    try {
      HiveService.saveCachedAdminKeyCooldowns(
        _cooldownList
            .map((c) => {
                  'keyId': c.keyId,
                  'until': c.until.toIso8601String(),
                })
            .toList(),
      );
    } catch (e) {
      debugPrint('[ApiKeyManager] Cooldown cache save error: $e');
    }
  }

  /// Pushes usage/error stats to the key's Firestore doc so the admin screen
  /// shows live numbers. Fire-and-forget: failures here must never break the
  /// AI call itself, so any error is swallowed after logging.
  Future<void> _updateKeyStats(String keyId,
      {int usageDelta = 0, DateTime? lastErrorAt}) async {
    try {
      final data = <String, dynamic>{};
      if (usageDelta > 0) {
        data['usageCount'] = FieldValue.increment(usageDelta);
        data['lastUsedAt'] = FieldValue.serverTimestamp();
      }
      if (lastErrorAt != null) {
        data['errorCount'] = FieldValue.increment(1);
        data['lastErrorAt'] = lastErrorAt;
      }
      if (data.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('admin_api_keys')
          .doc(keyId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ApiKeyManager] Stats update error: $e');
    }
  }

  /// Marks a key inactive in Firestore so the change propagates to every
  /// device via the snapshot listener. Only admin writes pass the rules;
  /// non-admin devices fail silently, which is fine — the first admin device
  /// to hit the failure threshold does the deactivation.
  Future<void> _deactivateKey(String keyId) async {
    _consecutiveAuthFailures.remove(keyId);
    // Drop from the local pool so this device stops using it immediately.
    _keyPool = _keyPool.where((k) => k.id != keyId).toList();
    _saveToCache();
    try {
      await FirebaseFirestore.instance
          .collection('admin_api_keys')
          .doc(keyId)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '[ApiKeyManager] Auto-deactivated key $keyId (repeated auth failures)');
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to auto-deactivate key $keyId: $e');
    }
  }

  List<AdminApiKey> _getHealthyKeys() => _selector().getHealthyKeys();

  KeyPoolSelector _selector() => KeyPoolSelector(
        keys: _keyPool,
        groups: _groups,
        cooldowns: _cooldownList,
      );

  /// Snapshot of group configs (provider → group) for the admin UI.
  Map<String, AdminKeyGroup> get groupConfigs => Map.unmodifiable(_groups);

  void _startGroupListener() {
    _groupSub = FirebaseFirestore.instance
        .collection('admin_key_groups')
        .snapshots()
        .listen((snapshot) {
      _groups = {
        for (final doc in snapshot.docs)
          doc.id: AdminKeyGroup.fromMap(doc.data(), doc.id),
      };
      debugPrint('[ApiKeyManager] Groups updated: ${_groups.length}');
    }, onError: (e) {
      debugPrint('[ApiKeyManager] Groups listener error: $e');
    });
  }

  void _incrementUsage(String keyId) {
    final index = _keyPool.indexWhere((k) => k.id == keyId);
    if (index == -1) return;
    _keyPool[index] = _keyPool[index].copyWith(
      usageCount: _keyPool[index].usageCount + 1,
      lastUsedAt: DateTime.now(),
    );
    _saveToCache();
    // Push usage stats to Firestore so the admin screen shows live usage counts.
    unawaited(_updateKeyStats(keyId, usageDelta: 1));
  }

  String _classifyError(int statusCode) {
    if (statusCode == 0) return 'network_error';
    if (statusCode == 429) return 'rate_limit';
    if (statusCode == 401 || statusCode == 403) return 'auth_error';
    if (statusCode >= 500) return 'server_error';
    return 'unknown';
  }

  String _errorMessage(int statusCode) {
    switch (statusCode) {
      case 0:
        return 'Network error';
      case 429:
        return 'Rate limit exceeded';
      case 401:
        return 'Unauthorized — key may be invalid';
      case 403:
        return 'Forbidden';
      case 500:
        return 'Provider server error';
      default:
        return 'HTTP $statusCode';
    }
  }

  Duration _getCooldownDuration(int statusCode, String provider) {
    final group = _groups[provider];
    switch (statusCode) {
      case 429:
        final s = group?.rateLimitCooldownSeconds;
        return s != null ? Duration(seconds: s) : const Duration(seconds: 60);
      case 401:
      case 403:
        return const Duration(days: 365);
      case 500:
        final s = group?.serverErrorCooldownSeconds;
        return s != null ? Duration(seconds: s) : const Duration(seconds: 120);
      default:
        final s = group?.defaultCooldownSeconds;
        return s != null ? Duration(seconds: s) : const Duration(seconds: 30);
    }
  }

  void _handleAllKeysFailed() {
    if (_allKeysFailedNotified) {
      if (_lastAllKeysFailedNotification != null &&
          DateTime.now().difference(_lastAllKeysFailedNotification!) <
              _notificationDebounce) {
        return;
      }
    }

    _allKeysFailedNotified = true;
    _lastAllKeysFailedNotification = DateTime.now();
    _sendOneSignalNotification();
    unawaited(_writeAdminAlert());

    _notificationCooldownTimer?.cancel();
    _notificationCooldownTimer = Timer(_notificationDebounce, () {
      _allKeysFailedNotified = false;
    });
  }

  /// Writes an in-app alert doc so admins see the outage in the admin panel
  /// even without push notifications. Merge semantics: the doc stays until an
  /// admin dismisses it (sets resolved: true) from the admin screen.
  Future<void> _writeAdminAlert() async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_alerts')
          .doc('api_keys_failed')
          .set({
        'type': 'api_keys_failed',
        'message':
            '${_keyPool.length} key(s) failed. Users cannot use AI features. Please add new keys.',
        'keyCount': _keyPool.length,
        'at': FieldValue.serverTimestamp(),
        'resolved': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to write admin alert: $e');
    }
  }

  Future<void> _sendOneSignalNotification() async {
    try {
      final appId = HiveService.getOneSignalAppId();
      if (appId.isEmpty) {
        debugPrint('[ApiKeyManager] OneSignal app ID not configured');
        return;
      }

      final adminIds = await _getAdminPlayerIds();
      if (adminIds.isEmpty) {
        debugPrint('[ApiKeyManager] No admin player IDs found');
        return;
      }

      final restKey = HiveService.getOneSignalRestApiKey();
      if (restKey.isEmpty) {
        debugPrint('[ApiKeyManager] OneSignal REST key not configured');
        return;
      }

      final body = jsonEncode({
        'app_id': appId,
        'include_player_ids': adminIds,
        'headings': {'en': '🚨 All API Keys Failed!'},
        'contents': {
          'en':
              '${_keyPool.length} key(s) failed. Users cannot use AI features. Please add new keys.',
        },
        'priority': 10,
      });

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $restKey',
        },
        body: body,
      );
      debugPrint('[ApiKeyManager] OneSignal notification sent');
    } catch (e) {
      debugPrint('[ApiKeyManager] OneSignal error: $e');
    }
  }

  Future<List<String>> _getAdminPlayerIds() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_notification_targets')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((d) => d.data()['playerId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to get admin player IDs: $e');
      return [];
    }
  }

  /// Deletes error logs older than [_logRetention]. Firestore TTL requires a
  /// paid plan, so on the free plan we clean up from admin devices instead
  /// (rules allow admin read/delete on api_error_logs; non-admin devices fail
  /// silently). Throttled to [_logCleanupInterval].
  void _cleanupExpiredErrorLogs() {
    final now = DateTime.now();
    if (_lastLogCleanup != null &&
        now.difference(_lastLogCleanup!) < _logCleanupInterval) {
      return;
    }
    _lastLogCleanup = now;
    unawaited(() async {
      try {
        final expired = await FirebaseFirestore.instance
            .collection('api_error_logs')
            .where('timestamp', isLessThan: now.subtract(_logRetention))
            .limit(500)
            .get();
        if (expired.docs.isEmpty) return;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in expired.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint(
            '[ApiKeyManager] Cleaned up ${expired.docs.length} expired error logs');
      } catch (e) {
        debugPrint('[ApiKeyManager] Error log cleanup failed: $e');
      }
    }());
  }

  /// Adds an error to the batched queue, dropping the oldest entry when the
  /// hard cap is hit, and flushing as soon as the batch size is reached.
  void _enqueueError(ApiErrorLog log) {
    _errorQueue.add(log);
    if (_errorQueue.length > _maxErrorQueue) {
      _errorQueue.removeAt(0);
    }
    if (_errorQueue.length >= _batchSize) {
      _flushErrorQueue();
    }
  }

  Future<void> _flushErrorQueue() async {
    if (_errorQueue.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final logsToWrite = List<ApiErrorLog>.from(_errorQueue);
    _errorQueue.clear();

    for (final error in logsToWrite) {
      final docRef =
          FirebaseFirestore.instance.collection('api_error_logs').doc();
      batch.set(docRef, error.toMap());
    }

    try {
      await batch.commit();
      debugPrint('[ApiKeyManager] Flushed ${logsToWrite.length} error logs');
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to flush error logs: $e');
      _errorQueue.addAll(logsToWrite);
      if (_errorQueue.length > _maxErrorQueue) {
        _errorQueue.removeRange(0, _errorQueue.length - _maxErrorQueue);
      }
    }
  }
}
