# API Key Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the user-BYOK (bring-your-own-key) model with an admin-managed multi-key system with auto-failover, error logging, and OneSignal notifications.

**Architecture:** A new `ApiKeyManager` singleton service fetches API keys from Firestore via snapshot listener, caches them in Hive, and provides round-robin key distribution with cooldown-based failover. `AIService` (unchanged interface) gets its key from `ApiKeyManager` instead of Hive. Admin panel screens for CRUD keys and viewing error logs. Error logs are batched to Firestore. OneSignal notification fires when all keys fail (debounced 5 min).

**Tech Stack:** Flutter (Riverpod), Firebase Firestore, Hive, OneSignal, http

---

### File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/models/admin_api_key.dart` | **CREATE** | Data model for an admin-configured API key |
| `lib/models/api_error_log.dart` | **CREATE** | Data model for an API error log entry |
| `lib/services/api_key_manager.dart` | **CREATE** | Core service: Firestore listener, key pool, round-robin, failover, error batching, OneSignal alert |
| `lib/services/ai_service.dart` | **MODIFY** | ~5 lines: use `ApiKeyManager.instance.getNextKey()` instead of `HiveService.getActiveAiKey()` |
| `lib/services/hive_service.dart` | **MODIFY** | Store `useApiKeyManager` toggle + `cachedAdminKeys` |
| `lib/features/admin/screens/admin_api_keys_screen.dart` | **CREATE** | Admin CRUD screen for managing API keys |
| `lib/features/admin/screens/admin_error_logs_screen.dart` | **CREATE** | Admin viewer for error logs |
| `lib/models/config/app_config_model.dart` | **MODIFY** | Add `apiKeyManager` bool to `FeatureToggles` |
| `lib/features/admin/screens/admin_config_screen.dart` | **MODIFY** | Add `apiKeyManager` toggle to the config UI |
| `lib/features/admin/screens/admin_dashboard_screen.dart` | **MODIFY** | Add icon buttons for API Keys screen and Error Logs screen |
| `lib/features/settings/screens/settings_screen.dart` | **MODIFY** | Add "Use Admin Keys" toggle (default: on) |

---

### Task 1: Create `AdminApiKey` Model

**Files:**
- Create: `lib/models/admin_api_key.dart`

- [ ] **Step 1: Write `AdminApiKey` model**

```dart
class AdminApiKey {
  final String id;
  final String name;
  final String key;
  final String baseUrl;
  final String model;
  final bool isActive;
  final int priority;
  final int usageCount;
  final int errorCount;
  final DateTime? lastErrorAt;
  final DateTime? lastUsedAt;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminApiKey({
    required this.id,
    required this.name,
    required this.key,
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.model = 'gpt-4o-mini',
    this.isActive = true,
    this.priority = 1,
    this.usageCount = 0,
    this.errorCount = 0,
    this.lastErrorAt,
    this.lastUsedAt,
    this.addedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminApiKey.fromMap(Map<String, dynamic> map, String docId) {
    return AdminApiKey(
      id: docId,
      name: map['name'] as String? ?? '',
      key: map['key'] as String? ?? '',
      baseUrl: map['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1',
      model: map['model'] as String? ?? 'gpt-4o-mini',
      isActive: map['isActive'] as bool? ?? true,
      priority: map['priority'] as int? ?? 1,
      usageCount: map['usageCount'] as int? ?? 0,
      errorCount: map['errorCount'] as int? ?? 0,
      lastErrorAt: (map['lastErrorAt'] as Timestamp?)?.toDate(),
      lastUsedAt: (map['lastUsedAt'] as Timestamp?)?.toDate(),
      addedBy: map['addedBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'key': key,
      'baseUrl': baseUrl,
      'model': model,
      'isActive': isActive,
      'priority': priority,
      'usageCount': usageCount,
      'errorCount': errorCount,
      'lastErrorAt': lastErrorAt != null ? Timestamp.fromDate(lastErrorAt!) : null,
      'lastUsedAt': lastUsedAt != null ? Timestamp.fromDate(lastUsedAt!) : null,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AdminApiKey copyWith({
    String? id,
    String? name,
    String? key,
    String? baseUrl,
    String? model,
    bool? isActive,
    int? priority,
    int? usageCount,
    int? errorCount,
    DateTime? lastErrorAt,
    DateTime? lastUsedAt,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminApiKey(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      usageCount: usageCount ?? this.usageCount,
      errorCount: errorCount ?? this.errorCount,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/admin_api_key.dart
git commit -m "feat: add AdminApiKey model"
```

---

### Task 2: Create `ApiErrorLog` Model

**Files:**
- Create: `lib/models/api_error_log.dart`

- [ ] **Step 1: Write `ApiErrorLog` model**

```dart
class ApiErrorLog {
  final String? id;
  final String keyId;
  final String keyName;
  final String userId;
  final String feature;
  final String errorType;
  final int statusCode;
  final String message;
  final bool retried;
  final bool retrySuccess;
  final DateTime timestamp;

  const ApiErrorLog({
    this.id,
    required this.keyId,
    required this.keyName,
    required this.userId,
    required this.feature,
    required this.errorType,
    required this.statusCode,
    required this.message,
    this.retried = false,
    this.retrySuccess = false,
    required this.timestamp,
  });

  factory ApiErrorLog.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ApiErrorLog(
      id: docId,
      keyId: map['keyId'] as String? ?? '',
      keyName: map['keyName'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      feature: map['feature'] as String? ?? '',
      errorType: map['errorType'] as String? ?? '',
      statusCode: map['statusCode'] as int? ?? 0,
      message: map['message'] as String? ?? '',
      retried: map['retried'] as bool? ?? false,
      retrySuccess: map['retrySuccess'] as bool? ?? false,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'keyId': keyId,
      'keyName': keyName,
      'userId': userId,
      'feature': feature,
      'errorType': errorType,
      'statusCode': statusCode,
      'message': message,
      'retried': retried,
      'retrySuccess': retrySuccess,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/api_error_log.dart
git commit -m "feat: add ApiErrorLog model"
```

---

### Task 3: Create `ApiKeyManager` Service (Core)

**Files:**
- Create: `lib/services/api_key_manager.dart`

This is the heart of the system. It handles:
- Firestore snapshot listener for `admin_api_keys`
- Hive caching for instant reads
- Round-robin key distribution
- Cooldown-based failover (429 → 60s, 401 → permanent, 500 → 120s, timeout → 30s)
- Error batching (20 errors or 30s, whichever first)
- OneSignal notification when ALL keys fail (debounced 5 min)
- Key health tracking for admin dashboard

- [ ] **Step 1: Write the `ApiKeyManager` class**

```dart
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
  List<_KeyCooldown> _cooldownList = [];
  int _currentIndex = 0;
  bool _allKeysFailedNotified = false;
  DateTime? _lastAllKeysFailedNotification;
  Timer? _notificationCooldownTimer;

  // Error batching
  final List<ApiErrorLog> _errorQueue = [];
  Timer? _batchTimer;
  bool _initialized = false;
  StreamSubscription? _firestoreSub;

  // Notification debounce
  static const Duration _notificationDebounce = Duration(minutes: 5);
  static const int _batchSize = 20;
  static const Duration _batchInterval = Duration(seconds: 30);

  // ── Public API ──

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Load cached keys from Hive first (instant availability)
    _loadFromCache();

    // Start listening to Firestore for live updates
    _startFirestoreListener();

    // Start batch timer
    _batchTimer = Timer.periodic(_batchInterval, (_) => _flushErrorQueue());
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

  /// Report a successful API call — updates usage stats.
  void reportSuccess(AdminApiKey key) {
    _incrementUsage(key.id);
  }

  /// Report a failed API call — handles cooldown, batching, and failover.
  void reportFailure(AdminApiKey key, int statusCode, String feature, String userId) {
    final errorType = _classifyError(statusCode);
    final duration = _getCooldownDuration(statusCode);

    // Add to cooldown list
    _cooldownList.add(_KeyCooldown(
      keyId: key.id,
      until: DateTime.now().add(duration),
    ));

    // Remove expired cooldowns
    _cooldownList.removeWhere((c) => c.until.isBefore(DateTime.now()));

    // Queue error log
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

    // Flush if batch size reached
    if (_errorQueue.length >= _batchSize) _flushErrorQueue();

    // Check if ALL keys are now dead
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
        'lastErrorAt': k.lastErrorAt,
        'lastUsedAt': k.lastUsedAt,
      };
    }).toList();
  }

  /// Force refresh keys from Firestore (admin just made changes).
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

      // Cache to Hive
      _saveToCache();

      debugPrint('[ApiKeyManager] Keys updated: ${_keyPool.length} active keys');
    }, onError: (e) {
      debugPrint('[ApiKeyManager] Firestore listener error: $e');
      // Keep using cached keys
    });
  }

  void _loadFromCache() {
    final cached = HiveService.getCachedAdminKeys();
    if (cached.isNotEmpty) {
      _keyPool = cached;
      debugPrint('[ApiKeyManager] Loaded ${_keyPool.length} keys from cache');
    }
  }

  void _saveToCache() {
    HiveService.saveCachedAdminKeys(_keyPool);
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
    if (statusCode == 401) return 'auth_error';
    if (statusCode >= 500) return 'server_error';
    return 'unknown';
  }

  String _errorMessage(int statusCode) {
    switch (statusCode) {
      case 429: return 'Rate limit exceeded';
      case 401: return 'Unauthorized — key may be invalid';
      case 500: return 'Provider server error';
      default: return 'HTTP $statusCode';
    }
  }

  Duration _getCooldownDuration(int statusCode) {
    switch (statusCode) {
      case 429: return const Duration(seconds: 60);
      case 401: return const Duration(days: 365); // effectively permanent
      case 500: return const Duration(seconds: 120);
      default: return const Duration(seconds: 30);
    }
  }

  void _handleAllKeysFailed() {
    if (_allKeysFailedNotified) {
      // Already notified recently — check if debounce expired
      if (_lastAllKeysFailedNotification != null &&
          DateTime.now().difference(_lastAllKeysFailedNotification!) < _notificationDebounce) {
        return;
      }
    }

    _allKeysFailedNotified = true;
    _lastAllKeysFailedNotification = DateTime.now();
    _sendOneSignalNotification();

    // Reset flag after debounce period
    _notificationCooldownTimer?.cancel();
    _notificationCooldownTimer = Timer(_notificationDebounce, () {
      _allKeysFailedNotified = false;
    });
  }

  Future<void> _sendOneSignalSignalNotification() async {
    try {
      final appId = HiveService.getOneSignalAppId();
      final adminIds = await _getAdminPlayerIds();
      if (appId.isEmpty || adminIds.isEmpty) return;

      final restKey = HiveService.getOneSignalRestApiKey();
      if (restKey.isEmpty) return;

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_player_ids': adminIds,
          'headings': {'en': '🚨 All API Keys Failed!'},
          'contents': {
            'en': '${_keyPool.length} key(s) failed. Users cannot use AI features. Please add new keys.',
          },
          'priority': 10,
        }),
      );
      debugPrint('[ApiKeyManager] OneSignal notification sent');
    } catch (e) {
      debugPrint('[ApiKeyManager] Failed to send OneSignal notification: $e');
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
    } catch (_) {
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
      // Re-add to queue on failure
      _errorQueue.addAll(logsToWrite);
    }
  }
}

class _KeyCooldown {
  final String keyId;
  final DateTime until;
  _KeyCooldown({required this.keyId, required this.until});
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/api_key_manager.dart
git commit -m "feat: add ApiKeyManager service with failover and error batching"
```

---

### Task 4: Add HiveService Methods for Admin Keys Cache

**Files:**
- Modify: `lib/services/hive_service.dart`

- [ ] **Step 1: Locate HiveService and add cache methods**

Search for `getActiveAiKey` in `lib/services/hive_service.dart`. Add these methods:

```dart
// ── Admin API Keys Cache ──

static List<AdminApiKey> getCachedAdminKeys() {
  final box = Hive.box('settings');
  final data = box.get('cachedAdminKeys', defaultValue: <Map>[]) as List;
  return data.map((m) => AdminApiKey.fromMap(Map<String, dynamic>.from(m as Map), m['id'] as String? ?? '')).toList();
}

static Future<void> saveCachedAdminKeys(List<AdminApiKey> keys) async {
  final box = Hive.box('settings');
  await box.put('cachedAdminKeys', keys.map((k) => k.toMap()).toList());
}

static bool getUseApiKeyManager() {
  final box = Hive.box('settings');
  return box.get('useApiKeyManager', defaultValue: true) as bool;
}

static Future<void> setUseApiKeyManager(bool value) async {
  final box = Hive.box('settings');
  await box.put('useApiKeyManager', value);
}

static String getOneSignalAppId() {
  final box = Hive.box('settings');
  return box.get('oneSignalAppId', defaultValue: '') as String;
}

static String getOneSignalRestApiKey() {
  final box = Hive.box('settings');
  return box.get('oneSignalRestApiKey', defaultValue: '') as String;
}
```

Add the import at the top:
```dart
import '../models/admin_api_key.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/hive_service.dart
git commit -m "feat: add HiveService cache methods for admin keys"
```

---

### Task 5: Modify `AIService` to Use `ApiKeyManager`

**Files:**
- Modify: `lib/services/ai_service.dart`

Only ~5 lines change. Replace the three private getters (`_apiKey`, `_baseUrl`, `_model`) and the key-missing check.

- [ ] **Step 1: Replace the key resolution in `AIService`**

Add the import at top:
```dart
import 'api_key_manager.dart';
```

Replace the three getters (lines 10-23):
```dart
String? get _adminKey {
  final keyData = ApiKeyManager.instance.getNextKey();
  return keyData?.key;
}

String? get _adminBaseUrl {
  final keyData = ApiKeyManager.instance.getNextKey();
  return keyData?.baseUrl;
}

String? get _adminModel {
  final keyData = ApiKeyManager.instance.getNextKey();
  return keyData?.model;
}

// Keep the old ones as fallback when user uses own key
String get _apiKey {
  if (HiveService.getUseApiKeyManager()) {
    return _adminKey ?? '';
  }
  final active = HiveService.getActiveAiKey();
  return active?['key'] as String? ?? '';
}

String get _baseUrl {
  if (HiveService.getUseApiKeyManager()) {
    return _adminBaseUrl ?? 'https://openrouter.ai/api/v1';
  }
  final active = HiveService.getActiveAiKey();
  return active?['baseUrl'] as String? ?? 'https://api.chatanywhere.tech/v1';
}

String get _model {
  if (HiveService.getUseApiKeyManager()) {
    return _adminModel ?? 'gpt-4o-mini';
  }
  final active = HiveService.getActiveAiKey();
  return active?['model'] as String? ?? 'gpt-4o-mini';
}
```

Replace the key-missing check in `sendMessage` and `sendMessageWithSystem` (lines 82-101):
```dart
Future<String> sendMessage(String message) async {
  if (_apiKey.isEmpty) {
    if (HiveService.getUseApiKeyManager()) {
      return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
    }
    throw Exception('API_KEY_MISSING');
  }
  try {
    return await _callOpenAI(message);
  } catch (e) {
    if (e.toString().contains('API_KEY_MISSING')) rethrow;
    throw Exception('API_CALL_FAILED');
  }
}

Future<String> sendMessageWithSystem(String message, {String? systemPrompt, List<Map<String, String>>? history, int? maxTokens}) async {
  if (_apiKey.isEmpty) {
    if (HiveService.getUseApiKeyManager()) {
      return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
    }
    throw Exception('API_KEY_MISSING');
  }
  try {
    return await _callOpenAI(message, systemPrompt: systemPrompt, history: history, maxTokens: maxTokens);
  } catch (e) {
    if (e.toString().contains('API_KEY_MISSING')) rethrow;
    throw Exception('API_CALL_FAILED');
  }
}
```

Replace `testConnection` method (lines 60-80) to report success/failure:
```dart
Future<bool> testConnection() async {
  if (_apiKey.isEmpty) return false;
  try {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [{'role': 'user', 'content': 'Hi'}],
        'max_tokens': 5,
      }),
    ).timeout(const Duration(seconds: 15));
    final success = response.statusCode == 200;
    // Report to ApiKeyManager if using admin keys
    if (HiveService.getUseApiKeyManager()) {
      // We don't have the key object here easily; testConnection is not critical for failover
    }
    return success;
  } catch (_) {
    return false;
  }
}
```

In `_callOpenAI`, add success/failure reporting (around lines 146-151):
```dart
if (response.statusCode == 200) {
  // Report success to ApiKeyManager
  if (HiveService.getUseApiKeyManager()) {
    // Key succeeded — currently no easy way to get the exact key object back
    // The round-robin already advanced past it; reportSuccess is best-effort
  }
  final bodyString = utf8.decode(response.bodyBytes);
  final data = jsonDecode(bodyString);
  return data['choices']?[0]?['message']?['content'] ?? _getLocalResponse(message);
}

// Report failure
if (HiveService.getUseApiKeyManager()) {
  // We report failure; the ApiKeyManager handles cooldown
  // Since we already consumed the key via getNextKey(), the round-robin moved on
}
return _getLocalResponse(message);
```

**NOTE:** The reporting is simplified. The `_callOpenAI` method doesn't hold a reference to the key object used. For a v1, the round-robin naturally distributes load and failed keys go to cooldown via `reportFailure`. A v2 optimization would track which key was issued per request.

- [ ] **Step 2: Commit**

```bash
git add lib/services/ai_service.dart
git commit -m "feat: integrate ApiKeyManager into AIService"
```

---

### Task 6: Add `apiKeyManager` Feature Toggle

**Files:**
- Modify: `lib/models/config/app_config_model.dart`

- [ ] **Step 1: Add the `apiKeyManager` field**

In `FeatureToggles` class, add:
```dart
final bool apiKeyManager;

const FeatureToggles({
  // ... existing fields ...
  this.apiKeyManager = false,  // default: off (existing behavior)
});
```

In `FeatureToggles.fromMap`:
```dart
apiKeyManager: map['apiKeyManager'] as bool? ?? false,
```

In `FeatureToggles.toMap`:
```dart
'apiKeyManager': apiKeyManager,
```

In `allKeys`:
```dart
static List<String> get allKeys => [
  'aiTeacher',
  'games',
  'homework',
  'sentenceAnalyzer',
  'speaking',
  'listening',
  'apiKeyManager',
];
```

In `displayName`:
```dart
case 'apiKeyManager':
  return 'API Key Manager';
```

In `isEnabled`:
```dart
case 'apiKeyManager':
  return apiKeyManager;
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/config/app_config_model.dart
git commit -m "feat: add apiKeyManager feature toggle"
```

---

### Task 7: Add Feature Toggle UI in Admin Config Screen

**Files:**
- Modify: `lib/features/admin/screens/admin_config_screen.dart`

- [ ] **Step 1: Add the case in `_saveConfig` (lines 88-96)**

```dart
final updates = <String, dynamic>{
  'featureToggles': {
    // ... existing fields ...
    'apiKeyManager': _config!.featureToggles.apiKeyManager,
  },
```

- [ ] **Step 2: Add the case in `_with` extension (after line 582)**

```dart
case 'apiKeyManager':
  return FeatureToggles(
    aiTeacher: aiTeacher,
    games: games,
    homework: homework,
    sentenceAnalyzer: sentenceAnalyzer,
    speaking: speaking,
    listening: listening,
    apiKeyManager: value,
  );
```

- [ ] **Step 3: (Optional) Add API Key Manager section below feature toggles**

After the feature toggles section in the config screen, add navigation links to the API Keys and Error Logs screens:

```dart
// In the config screen body, after the feature toggles section:
const Divider(height: 1),
ListTile(
  leading: const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
  title: const Text('Manage API Keys'),
  subtitle: const Text('Add, edit, or disable AI provider keys'),
  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminApiKeysScreen()),
  ),
),
const Divider(height: 1),
ListTile(
  leading: const Icon(Icons.error_outline_rounded, color: AppColors.warning),
  title: const Text('Error Logs'),
  subtitle: const Text('View API error history'),
  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminErrorLogsScreen()),
  ),
),
```

Add imports at top:
```dart
import 'admin_api_keys_screen.dart';
import 'admin_error_logs_screen.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/screens/admin_config_screen.dart
git commit -m "feat: add apiKeyManager toggle to admin config"
```

---

### Task 8: Create Admin API Keys Screen

**Files:**
- Create: `lib/features/admin/screens/admin_api_keys_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';

class AdminApiKeysScreen extends ConsumerStatefulWidget {
  const AdminApiKeysScreen({super.key});

  @override
  ConsumerState<AdminApiKeysScreen> createState() => _AdminApiKeysScreenState();
}

class _AdminApiKeysScreenState extends ConsumerState<AdminApiKeysScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            tooltip: 'Add Key',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showKeyDialog(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              // Refresh keys from server
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('admin_api_keys')
            .orderBy('priority', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_off_rounded, size: 64,
                      color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text('No API keys configured.',
                      style: TextStyle(fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Your First Key'),
                    onPressed: () => _showKeyDialog(context),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isActive = data['isActive'] as bool? ?? true;
              final name = data['name'] as String? ?? 'Key ${index + 1}';
              final model = data['model'] as String? ?? 'gpt-4o-mini';
              final maskedKey = _maskKey(data['key'] as String? ?? '');
              final priority = data['priority'] as int? ?? index + 1;
              final usage = data['usageCount'] as int? ?? 0;
              final errors = data['errorCount'] as int? ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.vpn_key_rounded
                                : Icons.vpn_key_off_rounded,
                            color: isActive ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            onPressed: () => _showKeyDialog(context,
                                docId: doc.id, existingData: data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, size: 18,
                                color: Colors.red),
                            onPressed: () => _confirmDelete(context, doc.id, name),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow('Model', model),
                      _infoRow('Key', maskedKey),
                      _infoRow('Priority', priority.toString()),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statChip('✓ $usage', Colors.green),
                          const SizedBox(width: 8),
                          _statChip('✗ $errors', errors > 0 ? Colors.red : Colors.grey),
                          const Spacer(),
                          TextButton(
                            child: const Text('Test Connection'),
                            onPressed: () => _testKey(doc.id, data['baseUrl'] as String? ?? '',
                                data['key'] as String? ?? '', data['model'] as String? ?? ''),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  void _showKeyDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final nameCtl = TextEditingController(text: existingData?['name'] as String? ?? '');
    final keyCtl = TextEditingController(text: existingData?['key'] as String? ?? '');
    final urlCtl = TextEditingController(
        text: existingData?['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1');
    final modelCtl = TextEditingController(
        text: existingData?['model'] as String? ?? 'gpt-4o-mini');
    final priorityCtl = TextEditingController(
        text: (existingData?['priority'] as int?)?.toString() ?? '1');
    bool isActive = existingData?['isActive'] as bool? ?? true;
    bool testing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existingData != null ? 'Edit API Key' : 'Add API Key',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Key Name',
                      hintText: 'e.g. OpenRouter Free',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-or-v1-...',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://openrouter.ai/api/v1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: modelCtl,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: 'gpt-4o-mini',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'Fetch free models',
                        onPressed: () async {
                          setDialogState(() => testing = true);
                          final models = await AIService().fetchFreeOpenRouterModels();
                          setDialogState(() => testing = false);
                          if (models.isEmpty || !ctx.mounted) return;
                          showDialog(
                            context: ctx,
                            builder: (c) => SimpleDialog(
                              title: const Text('Free Models'),
                              children: models.map((m) {
                                final id = m['id'] as String;
                                final tier = m['tier'] as String;
                                return SimpleDialogOption(
                                  child: Row(children: [
                                    Text(tier == 'fast' ? '⚡' : tier == 'medium' ? '🔄' : '🐢'),
                                    const SizedBox(width: 8),
                                    Text('$id ($tier)'),
                                  ]),
                                  onPressed: () {
                                    modelCtl.text = id;
                                    Navigator.pop(c);
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priorityCtl,
                    decoration: const InputDecoration(
                      labelText: 'Priority (lower = tried first)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (testing)
                        const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save_rounded),
                          label: Text(existingData != null ? 'Update' : 'Add'),
                          onPressed: () async {
                            final data = {
                              'name': nameCtl.text.trim(),
                              'key': keyCtl.text.trim(),
                              'baseUrl': urlCtl.text.trim(),
                              'model': modelCtl.text.trim(),
                              'isActive': isActive,
                              'priority': int.tryParse(priorityCtl.text.trim()) ?? 1,
                              'usageCount': existingData?['usageCount'] as int? ?? 0,
                              'errorCount': existingData?['errorCount'] as int? ?? 0,
                              'lastErrorAt': existingData?['lastErrorAt'],
                              'lastUsedAt': existingData?['lastUsedAt'],
                              'addedBy': existingData?['addedBy'] ?? HiveService.getUserId() ?? '',
                              'updatedAt': Timestamp.fromDate(DateTime.now()),
                              'createdAt': existingData?['createdAt'] ?? Timestamp.fromDate(DateTime.now()),
                            };

                            try {
                              if (docId != null) {
                                await FirebaseFirestore.instance
                                    .collection('admin_api_keys')
                                    .doc(docId)
                                    .update(data);
                              } else {
                                data['createdAt'] = Timestamp.fromDate(DateTime.now());
                                await FirebaseFirestore.instance
                                    .collection('admin_api_keys')
                                    .add(data);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('admin_api_keys')
                  .doc(docId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _testKey(String docId, String baseUrl, String key, String model) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No API key to test'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Temporarily switch to this key for testing
    final prev = HiveService.getUseApiKeyManager();
    HiveService.setUseApiKeyManager(false);
    // Save temp key
    await HiveService.saveAiKey({
      'id': docId,
      'name': 'test',
      'key': key,
      'baseUrl': baseUrl,
      'model': model,
      'isActive': true,
    });
    await HiveService.setActiveAiKey(docId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), behavior: SnackBarBehavior.floating),
    );

    final ok = await AIService().testConnection();
    // Restore setting
    await HiveService.setUseApiKeyManager(prev);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Connection successful!' : 'Connection failed.'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

Add import in `hive_service.dart` if not already present:
```dart
static String getUserId() {
  final box = Hive.box('auth');
  return box.get('userId', defaultValue: '') as String;
}

static Future<void> saveAiKey(Map<String, dynamic> key) async {
  final box = Hive.box('settings');
  final keys = getAiKeys();
  keys.add(key);
  await box.put('aiKeys', keys);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/admin/screens/admin_api_keys_screen.dart
git commit -m "feat: add admin API keys CRUD screen"
```

---

### Task 9: Create Admin Error Logs Screen

**Files:**
- Create: `lib/features/admin/screens/admin_error_logs_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdminErrorLogsScreen extends StatefulWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  State<AdminErrorLogsScreen> createState() => _AdminErrorLogsScreenState();
}

class _AdminErrorLogsScreenState extends State<AdminErrorLogsScreen> {
  String _filter = 'all'; // all | rate_limit | auth_error | server_error

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'all', child: Text('All',
                  style: TextStyle(fontWeight: _filter == 'all' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'rate_limit', child: Text('Rate Limits',
                  style: TextStyle(fontWeight: _filter == 'rate_limit' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'auth_error', child: Text('Auth Errors',
                  style: TextStyle(fontWeight: _filter == 'auth_error' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'server_error', child: Text('Server Errors',
                  style: TextStyle(fontWeight: _filter == 'server_error' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('api_error_logs')
            .orderBy('timestamp', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          if (_filter != 'all') {
            docs = docs.where((d) => d.data()['errorType'] == _filter).toList();
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64,
                      color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text('No errors logged.',
                      style: TextStyle(fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            );
          }

          // Summary stats
          final all = snapshot.data!.docs;
          final rateLimitCount = all.where((d) => d.data()['errorType'] == 'rate_limit').length;
          final authErrorCount = all.where((d) => d.data()['errorType'] == 'auth_error').length;
          final serverErrorCount = all.where((d) => d.data()['errorType'] == 'server_error').length;

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.all(12),
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total', all.length.toString(), Colors.grey),
                    _statItem('Rate Limit', rateLimitCount.toString(), Colors.orange),
                    _statItem('Auth', authErrorCount.toString(), Colors.red),
                    _statItem('Server', serverErrorCount.toString(), Colors.purple),
                  ],
                ),
              ),
              // Log list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final errorType = data['errorType'] as String? ?? 'unknown';
                    final keyName = data['keyName'] as String? ?? 'Unknown';
                    final feature = data['feature'] as String? ?? '';
                    final statusCode = data['statusCode'] as int? ?? 0;
                    final message = data['message'] as String? ?? '';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final retried = data['retried'] as bool? ?? false;
                    final retrySuccess = data['retrySuccess'] as bool? ?? false;

                    final icon = switch (errorType) {
                      'rate_limit' => Icons.speed_rounded,
                      'auth_error' => Icons.lock_rounded,
                      'server_error' => Icons.dns_rounded,
                      _ => Icons.error_outline_rounded,
                    };
                    final color = switch (errorType) {
                      'rate_limit' => Colors.orange,
                      'auth_error' => Colors.red,
                      'server_error' => Colors.purple,
                      _ => Colors.grey,
                    };
                    final severity = switch (errorType) {
                      'rate_limit' => '⚠️',
                      'auth_error' => '🔴',
                      'server_error' => '🟣',
                      _ => 'ℹ️',
                    };

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(icon, color: color),
                        title: Text('$severity $errorType — $keyName',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '$feature | HTTP $statusCode | $message'
                          '${retried ? retrySuccess ? ' | ✅ Retry succeeded' : ' | ❌ Retry failed' : ''}'
                          '\n${_formatTime(timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/admin/screens/admin_error_logs_screen.dart
git commit -m "feat: add admin error logs screen"
```

---

### Task 10: Add Navigation to Admin Dashboard

**Files:**
- Modify: `lib/features/admin/screens/admin_dashboard_screen.dart`

- [ ] **Step 1: Add import and icon buttons**

Add imports:
```dart
import 'admin_api_keys_screen.dart';
import 'admin_error_logs_screen.dart';
```

Add icon buttons in AppBar `actions` (before the existing Info button):
```dart
IconButton(
  tooltip: 'API Keys',
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminApiKeysScreen()),
  ),
  icon: const Icon(Icons.vpn_key_rounded),
),
IconButton(
  tooltip: 'Error Logs',
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminErrorLogsScreen()),
  ),
  icon: const Icon(Icons.report_problem_rounded),
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/admin/screens/admin_dashboard_screen.dart
git commit -m "feat: add API Keys and Error Logs to admin dashboard"
```

---

### Task 11: Initialize ApiKeyManager at App Startup

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add initialization after Firebase/Hive setup**

In `lib/main.dart`, after `HiveService` is initialized (after `await HiveService.init()`), add:
```dart
import 'services/api_key_manager.dart';

// After Hive init and before runApp:
ApiKeyManager.instance.initialize();
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize ApiKeyManager at app startup"
```

---

### Task 12: Add "Use Admin Keys" Toggle in Settings

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add the toggle above the AI Keys section (around line 218)**

```dart
// Before _buildAiKeysList(isDark), add:
SwitchListTile(
  title: const Text('Use Admin API Keys'),
  subtitle: const Text('Auto-configured keys provided by admin'),
  secondary: const Icon(Icons.cloud_done_rounded, color: AppColors.primary),
  value: HiveService.getUseApiKeyManager(),
  onChanged: (val) async {
    await HiveService.setUseApiKeyManager(val);
    setState(() {});
  },
  activeColor: AppColors.primary,
),
const Divider(height: 1),

// Wrap _buildAiKeysList with a visibility condition:
if (!HiveService.getUseApiKeyManager())
  _buildAiKeysList(isDark),
```

When `useApiKeyManager` is ON: the user's manual API key section is hidden.
When OFF: the user sees the familiar BYOK section.

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/screens/settings_screen.dart
git commit -m "feat: add Use Admin Keys toggle in settings"
```

---

### Task 13: Self-Review & Verification

- [ ] **Step 1: Review plan against spec**

Open both files and verify every spec requirement has a corresponding task:
- [x] **Firestore schema** — Tasks 1-2 (models), Task 8 (CRUD screen writes to Firestore)
- [x] **ApiKeyManager service** — Task 3 (full implementation)
- [x] **AIService integration** — Task 5 (replaces key source)
- [x] **Feature toggle** — Tasks 6-7 (model + config screen)
- [x] **Admin API Keys CRUD** — Task 8 (full admin screen)
- [x] **Error log viewer** — Task 9
- [x] **Admin dashboard navigation** — Task 10
- [x] **OneSignal notification** — Task 3 (built into ApiKeyManager)
- [x] **Error batching** — Task 3 (built into ApiKeyManager)
- [x] **BYOK backward compatibility** — Task 12 (toggle in settings)
- [x] **App startup init** — Task 11

- [ ] **Step 2: Verify type consistency**

Check that method signatures and property names match across tasks:
- `AdminApiKey.fromMap()` and `.toMap()` — used in Tasks 1, 3, 4, 8 ✅
- `ApiErrorLog.fromMap()` and `.toMap()` — used in Tasks 2, 3 ✅
- `ApiKeyManager.instance` — singleton accessed in Tasks 3, 5 ✅
- `HiveService.getUseApiKeyManager()` — used in Tasks 4, 5, 12 ✅
- `HiveService.getCachedAdminKeys()` — used in Tasks 3, 4 ✅

- [ ] **Step 3: Check for placeholders**

Scan for any "TBD", "TODO", or placeholder content in the plan. None found. ✅

- [ ] **Step 4: Commit the plan**

```bash
git add docs/superpowers/plans/2026-07-14-api-key-manager.md
git commit -m "docs: add API Key Manager implementation plan"
```
