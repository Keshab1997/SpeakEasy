import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/admin_api_key.dart';
import '../models/admin_key_group.dart';
import '../models/api_error_log.dart';
import 'hive_service.dart';

class ApiKeyManager {
  static final ApiKeyManager instance = ApiKeyManager._();
  ApiKeyManager._();

  // ── State ──
  List<AdminApiKey> _keyPool = [];
  Map<String, AdminKeyGroup> _groups = {};
  final List<_KeyCooldown> _cooldownList = [];
  final Completer<void> _readyCompleter = Completer<void>();
  int _currentIndex = 0;
  bool _allKeysFailedNotified = false;
  DateTime? _lastAllKeysFailedNotification;
  Timer? _notificationCooldownTimer;
  Timer? _batchTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupSub;

  // Error batching
  final List<ApiErrorLog> _errorQueue = [];
  bool _initialized = false;

  // Constants
  static const Duration _notificationDebounce = Duration(minutes: 5);
  static const int _batchSize = 20;
  static const Duration _batchInterval = Duration(seconds: 30);

  // ── Public API ──

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _loadFromCache();
    _loadCooldownsFromCache();
    _startFirestoreListener();
    _startGroupListener();
    _batchTimer = Timer.periodic(_batchInterval, (_) => _flushErrorQueue());
    debugPrint('[ApiKeyManager] initialized');
  }

  /// Returns the next healthy key from the highest-priority enabled group
  /// (round-robin within that group). Slower groups are used only as a
  /// fallback when every key of the preferred group is on cooldown, so the
  /// "fast" group carries the load while the rest wait in reserve.
  AdminApiKey? getNextKey() {
    final healthy = _getHealthyKeys();
    if (healthy.isEmpty) return null;

    final topPriority = _groupPriority(healthy.first.provider);
    final pool =
        healthy.where((k) => _groupPriority(k.provider) == topPriority).toList();

    if (_currentIndex >= pool.length) _currentIndex = 0;
    final key = pool[_currentIndex];
    _currentIndex = (_currentIndex + 1) % pool.length;
    return key;
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
    _incrementUsage(key.id);
  }

  /// Report a failed API call.
  void reportFailure(AdminApiKey key, int statusCode, String feature, String userId) {
    final errorType = _classifyError(statusCode);
    final duration = _getCooldownDuration(statusCode);

    _cooldownList.add(_KeyCooldown(
      keyId: key.id,
      until: DateTime.now().add(duration),
    ));
    _cooldownList.removeWhere((c) => c.until.isBefore(DateTime.now()));
    _saveCooldownsToCache();

    _errorQueue.add(ApiErrorLog(
      keyId: key.id,
      keyName: key.name,
      userId: userId,
      feature: feature,
      errorType: errorType,
      statusCode: statusCode,
      message: _errorMessage(statusCode),
      retried: true,
      retrySuccess: false,
      timestamp: DateTime.now(),
    ));

    if (_errorQueue.length >= _batchSize) {
      _flushErrorQueue();
    }

    // Push error stats to Firestore so the admin screen shows live error counts.
    unawaited(_updateKeyStats(key.id, lastErrorAt: DateTime.now()));

    if (_getHealthyKeys().isEmpty) {
      _handleAllKeysFailed();
    }
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
      debugPrint('[ApiKeyManager] Keys updated: ${_keyPool.length} active keys');
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
              .add(_KeyCooldown(keyId: c['keyId'] as String, until: until));
        }
      }
      debugPrint('[ApiKeyManager] Loaded ${_cooldownList.length} cooldowns from cache');
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

  List<AdminApiKey> _getHealthyKeys() {
    final now = DateTime.now();
    return _keyPool.where((k) {
      final isOnCooldown =
          _cooldownList.any((c) => c.keyId == k.id && c.until.isAfter(now));
      final groupEnabled = _groups[k.provider]?.enabled ?? true;
      return k.isActive && groupEnabled && !isOnCooldown;
    }).toList()
      ..sort((a, b) {
        final gp = _groupPriority(a.provider).compareTo(_groupPriority(b.provider));
        if (gp != 0) return gp;
        return a.priority.compareTo(b.priority);
      });
  }

  /// Priority of a provider's group (lower = tried first). Groups without a
  /// config doc default to 100 so they never shadow an explicitly ranked group.
  int _groupPriority(String provider) => _groups[provider]?.priority ?? 100;

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
      case 0: return 'Network error';
      case 429: return 'Rate limit exceeded';
      case 401: return 'Unauthorized — key may be invalid';
      case 403: return 'Forbidden';
      case 500: return 'Provider server error';
      default: return 'HTTP $statusCode';
    }
  }

  Duration _getCooldownDuration(int statusCode) {
    switch (statusCode) {
      case 429: return const Duration(seconds: 60);
      case 401: return const Duration(days: 365);
      case 403: return const Duration(days: 365);
      case 500: return const Duration(seconds: 120);
      default: return const Duration(seconds: 30);
    }
  }

  void _handleAllKeysFailed() {
    if (_allKeysFailedNotified) {
      if (_lastAllKeysFailedNotification != null &&
          DateTime.now().difference(_lastAllKeysFailedNotification!) < _notificationDebounce) {
        return;
      }
    }

    _allKeysFailedNotified = true;
    _lastAllKeysFailedNotification = DateTime.now();
    _sendOneSignalNotification();

    _notificationCooldownTimer?.cancel();
    _notificationCooldownTimer = Timer(_notificationDebounce, () {
      _allKeysFailedNotified = false;
    });
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
          'en': '${_keyPool.length} key(s) failed. Users cannot use AI features. Please add new keys.',
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

  Future<void> _flushErrorQueue() async {
    if (_errorQueue.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final logsToWrite = List<ApiErrorLog>.from(_errorQueue);
    _errorQueue.clear();

    for (final error in logsToWrite) {
      final docRef = FirebaseFirestore.instance.collection('api_error_logs').doc();
      batch.set(docRef, error.toMap());
    }

    try {
      await batch.commit();
      debugPrint('[ApiKeyManager] Flushed ${logsToWrite.length} error logs');
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to flush error logs: $e');
      _errorQueue.addAll(logsToWrite);
    }
  }
}

class _KeyCooldown {
  final String keyId;
  final DateTime until;
  _KeyCooldown({required this.keyId, required this.until});
}
