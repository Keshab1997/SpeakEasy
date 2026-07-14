import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/admin_api_key.dart';
import '../models/api_error_log.dart';
import 'hive_service.dart';

class ApiKeyManager {
  static final ApiKeyManager instance = ApiKeyManager._();
  ApiKeyManager._();

  // ── State ──
  List<AdminApiKey> _keyPool = [];
  final List<_KeyCooldown> _cooldownList = [];
  int _currentIndex = 0;
  bool _allKeysFailedNotified = false;
  DateTime? _lastAllKeysFailedNotification;
  Timer? _notificationCooldownTimer;
  Timer? _batchTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

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
    _startFirestoreListener();
    _batchTimer = Timer.periodic(_batchInterval, (_) => _flushErrorQueue());
    debugPrint('[ApiKeyManager] initialized');
  }

  /// Returns the next healthy key (round-robin, skipping cooldown keys).
  /// Returns null if all keys are exhausted or none configured.
  AdminApiKey? getNextKey() {
    final healthy = _getHealthyKeys();
    if (healthy.isEmpty) return null;

    if (_currentIndex >= healthy.length) _currentIndex = 0;
    final key = healthy[_currentIndex];
    _currentIndex = (_currentIndex + 1) % healthy.length;
    return key;
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

  void dispose() {
    _firestoreSub?.cancel();
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

  List<AdminApiKey> _getHealthyKeys() {
    final now = DateTime.now();
    return _keyPool.where((k) {
      final isOnCooldown = _cooldownList.any((c) => c.keyId == k.id && c.until.isAfter(now));
      return k.isActive && !isOnCooldown;
    }).toList();
  }

  void _incrementUsage(String keyId) {
    final index = _keyPool.indexWhere((k) => k.id == keyId);
    if (index == -1) return;
    _keyPool[index] = _keyPool[index].copyWith(
      usageCount: _keyPool[index].usageCount + 1,
      lastUsedAt: DateTime.now(),
    );
    _saveToCache();
  }

  String _classifyError(int statusCode) {
    if (statusCode == 429) return 'rate_limit';
    if (statusCode == 401 || statusCode == 403) return 'auth_error';
    if (statusCode >= 500) return 'server_error';
    return 'unknown';
  }

  String _errorMessage(int statusCode) {
    switch (statusCode) {
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
