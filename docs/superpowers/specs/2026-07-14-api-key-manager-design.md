# API Key Manager — Design Spec

**Date:** 2026-07-14
**Project:** SpeakEasy (Flutter)
**Status:** Approved for implementation

---

## 1. Overview

### 1.1 Problem

Currently, SpeakEasy users must bring their own OpenAI-compatible API key (BYOK) to use AI-powered features. This creates friction — users need to sign up for external services, find free API keys, and configure them manually.

### 1.2 Solution

Introduce a **server-side API key management system** where:
- **Admin** adds/configures API keys via an admin panel (Firestore)
- **Users** automatically use those keys without any manual setup
- **Failover** is automatic — if one key fails, the next is tried
- **Notifications** alert the admin when all keys fail

### 1.3 Scope — Which Features Use This?

| Feature | Screen | Uses AIService |
|---------|--------|---------------|
| AI Teacher | ai_chat_screen.dart | ✅ |
| AI Homework | homework_screen.dart | ✅ |
| Sentence Analyzer | sentence_analyzer_screen.dart | ✅ |
| Conversation (role-play) | conversation_screen.dart | ✅ |
| Grammar Master Quiz | grammar_master_screen.dart | ✅ |
| Banglish Translator | banglish_translator_screen.dart | ✅ |
| Admin Reply Generator | admin_repository.dart | ✅ |

*All 7 features go through AIService — changing AIService's key source updates everything.*

---

## 2. Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────┐
│                 Admin Panel                  │
│  ┌──────────────┐  ┌────────────────────┐   │
│  │ API Keys CRUD │  │ Error Log Viewer   │   │
│  └──────┬───────┘  └─────────┬──────────┘   │
└─────────┼────────────────────┼──────────────┘
          │ write/read         │ read
          ▼                    ▼
┌──────────────────────────────────────────────┐
│              Firestore                        │
│  ┌─────────────────┐  ┌──────────────────┐   │
│  │ admin_api_keys   │  │ api_error_logs   │   │
│  │ (collection)     │  │ (collection)     │   │
│  └────────┬────────┘  └────────┬─────────┘   │
└───────────┼───────────────────┼──────────────┘
            │ snapshot          │ batch write
            ▼                   ▼
┌──────────────────────────────────────────────┐
│          ApiKeyManager (NEW Service)          │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Key Pool │  │ Round-   │  │ Error      │ │
│  │ (cache)  │  │ Robin    │  │ Reporter   │ │
│  └──────────┘  └──────────┘  └──────┬─────┘ │
│                                      │       │
│  ┌──────────┐  ┌──────────┐         │       │
│  │ Key      │  │ Health   │         │       │
│  │ Fetcher  │  │ Tracker  │         │       │
│  └──────────┘  └──────────┘         │       │
└──────┬──────────────────────────────┼───────┘
       │ getActiveKey()               │
       ▼                              ▼
┌──────────────────┐        ┌─────────────────┐
└──────┬───────────┘        │  OneSignal API   │
       │                    │  (all keys fail) │
       ▼                    └─────────────────┘
┌──────────────────┐
│   AIService      │
│  (unchanged      │
│   interface)     │
└──────────────────┘
```

### 2.2 Data Flow — Normal Request

```
User sends message in AI Teacher
         │
         ▼
AIService.sendMessage(text)
         │
         ▼
AIService → ApiKeyManager.getActiveKey()
         │
         ▼
ApiKeyManager picks next key (round-robin from Hive cache)
         │
         ▼
AIService calls {baseUrl}/chat/completions with Bearer {key}
         │
         ▼
Success → Response returned to user
```

### 2.3 Data Flow — Failover Scenario

```
AIService.sendMessage(text)
         │
         ▼
Key 1 → HTTP 429 (Rate Limit)
         │
         ▼
ApiKeyManager.handleFailure(key1, 429)
  → Marks Key 1 as temporarily degraded (60s cooldown in memory)
  → Returns next key from pool
         │
         ▼
AIService retries with Key 2
         │
         ▼
Key 2 → Success ✅
         │
         ▼
Response returned to user (~300-500ms extra delay, imperceptible)
         │
         ▼
Error logged to local queue → batch write to Firestore later
```

### 2.4 Data Flow — All Keys Failed

```
All keys in pool exhausted (all failed)
         │
         ▼
ApiKeyManager
  ├─ Returns null to AIService → user sees "Service unavailable"
  ├─ Logs critical error to Firestore batch queue
  ├─ Triggers OneSignal notification to admin (debounced: 1/5min)
  └─ Saves "all_keys_failed" event to admin_notifications
```

---

## 3. ApiKeyManager Service — Detailed Design

### 3.1 File: `lib/services/api_key_manager.dart`

```dart
class ApiKeyManager {
  static final ApiKeyManager instance = ApiKeyManager._();
  
  // ── State ──
  List<AdminApiKey> _keyPool = [];          // Healthy keys
  List<AdminApiKey> _temporarilyBanned = [];// Keys on cooldown
  int _currentIndex = 0;
  bool _allKeysFailedNotified = false;
  
  // ── Public API ──
  
  /// Initialize: start Firestore snapshot listener
  Future<void> initialize();
  
  /// Get the next available key (round-robin, skipping degraded keys)
  AdminApiKey? getNextKey();
  
  /// Called by AIService when a key fails
  void reportFailure(AdminApiKey key, int statusCode, String feature, String userId);
  
  /// Called by AIService when a key succeeds
  void reportSuccess(AdminApiKey key);
  
  /// Get key health stats (for admin dashboard)
  List<KeyHealth> getKeyHealth();
  
  // ── Core Logic ──
  
  void _startFirestoreListener();
  void _processKeyFailure(AdminApiKey key, ...);
  void _tryFailover(AdminApiKey failedKey, ...);
  Future<void> _batchWriteErrors();
  Future<void> _sendAllKeysFailedNotification();
}
```

### 3.2 Key Properties

| Method | Behavior |
|--------|----------|
| `initialize()` | Start Firestore `snapshot()` listener on `admin_api_keys`; populate Hive cache |
| `getNextKey()` | Round-robin from healthy pool; skip cooldown keys; return null if all fail |
| `reportFailure()` | Increment error count; add to local error queue; trigger failover if needed |
| `reportSuccess()` | Increment usage count; reset health if previously degraded |

### 3.3 Cooldown Strategy

| Status Code | Cooldown Duration | Reason |
|-------------|-------------------|--------|
| 429 (Rate Limit) | 60 seconds | Transient — key likely works soon |
| 401 (Unauthorized) | Permanent (until admin re-enables) | Key invalid/expired |
| 500 (Server Error) | 120 seconds | Provider-side issue |
| Timeout | 30 seconds | Network issue, retry quickly |

---

## 4. Firestore Schema

### 4.1 `admin_api_keys` Collection

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| id | string | `key_001` | Auto-generated |
| name | string | `OpenRouter Free` | Admin label |
| key | string | `sk-or-v1-xxxxx` | Actual API key |
| baseUrl | string | `https://openrouter.ai/api/v1` | OpenAI-compatible base |
| model | string | `gpt-4o-mini` | Default model |
| isActive | bool | `true` | Admin toggle on/off |
| priority | int | `1` | Lower = tried first |
| usageCount | int | `1523` | Lifetime usage |
| errorCount | int | `12` | Lifetime errors |
| lastErrorAt | timestamp | `2026-07-14T10:30:00Z` | Last failure |
| lastUsedAt | timestamp | `2026-07-14T10:30:00Z` | Last success |
| addedBy | string | `admin_uid` | Admin who added |
| createdAt | timestamp | `2026-07-01T00:00:00Z` | Creation time |
| updatedAt | timestamp | `2026-07-14T10:30:00Z` | Last update |

**Security Rule:**
```
match /admin_api_keys/{doc} {
  allow read: if request.auth != null;  // any authenticated user
  allow write: if request.auth.token.admin == true;  // admin only
}
```

### 4.2 `api_error_logs` Collection

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| id | string | `err_001` | Auto-generated |
| keyId | string | `key_001` | Which key failed |
| keyName | string | `OpenRouter Free` | Denormalized for display |
| userId | string | `user_abc123` | Affected user |
| feature | string | `ai_teacher` | Which feature |
| errorType | string | `rate_limit` | Categorization |
| statusCode | int | `429` | HTTP status |
| message | string | `Rate limit exceeded` | Error details |
| retried | bool | `true` | Was failover attempted? |
| retrySuccess | bool | `true` | Did failover succeed? |
| timestamp | timestamp | `2026-07-14T10:30:00Z` | When error occurred |

**Security Rule:**
```
match /api_error_logs/{doc} {
  allow read: if request.auth != null && request.auth.token.admin == true;
  allow write: if request.auth != null;  // users can write error logs
}
```

### 4.3 `admin_notifications` Collection (Optional, for Dashboard History)

| Field | Type | Example |
|-------|------|---------|
| id | string | `notif_001` |
| type | string | `all_keys_failed` |
| severity | string | `critical` |
| title | string | `🚨 সব API key ব্যর্থ!` |
| body | string | `১৫ জন user প্রভাবিত। দয়া করে নতুন key যোগ করুন।` |
| triggeredAt | timestamp | `2026-07-14T10:30:00Z` |
| resolvedAt | timestamp | `null` |
| notifiedAdminIds | array | `[admin_uid]` |

---

## 5. Admin Panel Screens

### 5.1 File: `lib/features/admin/screens/admin_api_keys_screen.dart`

A new screen accessible from the existing admin dashboard:

```
┌─────────────────────────────────────┐
│  ⚙️ API Keys Management      [+Add] │
├─────────────────────────────────────┤
│ 🔑 OpenRouter Free      ● Active   │
│    Model: gpt-4o-mini              │
│    Used: 1,523 | Errors: 12        │
│    [Edit] [Disable] [Delete]       │
├─────────────────────────────────────┤
│ 🔑 DeepSeek Chat        ○ Inactive │
│    Model: deepseek-chat            │
│    Used: 892 | Errors: 3          │
│    [Edit] [Enable] [Delete]       │
├─────────────────────────────────────┤
│ 🔑 ChatAnywhere         ● Active   │
│    Model: gpt-4o-mini              │
│    Used: 2,101 | Errors: 0         │
│    [Edit] [Disable] [Delete]       │
├─────────────────────────────────────┤
│  💚 Key Health Summary              │
│  ┌──────┬──────┬──────┐            │
│  │ ✅   │ ⚠️   │ ❌   │            │
│  │ 89%  │ 45%  │ 0%   │            │
│  └──────┴──────┴──────┘            │
└─────────────────────────────────────┘
```

**Add/Edit Dialog Fields:**
- Name (text)
- API Key (text, obscured)
- Base URL (text, pre-filled: `https://openrouter.ai/api/v1`)
- Model (text + "Fetch Free Models" button from OpenRouter)
- Priority (number 1-10)
- Is Active (toggle)

### 5.2 File: `lib/features/admin/screens/admin_error_logs_screen.dart`

```
┌─────────────────────────────────────┐
│  ❌ API Error Logs          [Filter]│
├─────────────────────────────────────┤
│ 🔴 High: All keys failed (15m ago) │
│ ⚠️  429 Rate Limit - Key 1 (2m ago)│
│ ℹ️  401 Auth - Key 2 (5m ago)      │
│ ℹ️  500 Server - Key 3 (10m ago)   │
├─────────────────────────────────────┤
│ 📊 Last 24h: 45 errors             │
│    • rate_limit: 30                │
│    • auth_error: 10                │
│    • server_error: 5               │
└─────────────────────────────────────┘
```

---

## 6. AIService Changes

### 6.1 Minimal Changes Required

The key change is **where AIService gets its API key**. Everything else stays:

```dart
// BEFORE: User's own key from Hive
var keyData = HiveService.getActiveAiKey();

// AFTER: Admin-provided key from ApiKeyManager
var keyData = ApiKeyManager.instance.getNextKey();
```

```dart
// lib/services/ai_service.dart — only ~3 lines change

// Remove: final keyData = HiveService.getActiveAiKey();
// Remove: 'Authorization': 'Bearer ${keyData['key']}'

// Add:
final keyData = ApiKeyManager.instance.getNextKey();
if (keyData == null) {
  return '⚠️ সার্ভার ব্যস্ত, কিছুক্ষণ পর আবার চেষ্টা করুন।';
}
// Use: keyData.key, keyData.baseUrl, keyData.model

// On success: ApiKeyManager.instance.reportSuccess(keyData);
// On failure: ApiKeyManager.instance.reportFailure(keyData, statusCode, ...);
```

**Additionally**, if the user still wants the option to use their own key (BYOK), add a toggle in Settings:
- "Use My Own API Key" (default: off)
- When ON: fall back to existing Hive-based key lookup (no change from current behavior)
- When OFF: use ApiKeyManager

---

## 7. OneSignal Notification Flow

### 7.1 When Notification Triggers

```
Condition: ALL keys in pool have failed AND cooldown not active
  → ApiKeyManager._sendAllKeysFailedNotification()

Implementation:
  1. Check _allKeysFailedNotified flag (debounce)
  2. If not notified in last 5 minutes:
     a. Create admin_notifications document in Firestore
     b. Call OneSignal REST API to send push to admin device(s)
     c. Set _allKeysFailedNotified = true
     d. Start 5-minute cooldown timer → reset flag
```

### 7.2 OneSignal API Call

```dart
Future<void> _sendAllKeysFailedNotification() async {
  final oneSignalAppId = await HiveService.getOneSignalAppId();
  final adminPlayerIds = await _getAdminPlayerIds();
  
  if (adminPlayerIds.isEmpty) return;
  
  // Use OneSignal REST API
  await http.post(
    Uri.parse('https://onesignal.com/api/v1/notifications'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $ONESIGNAL_REST_API_KEY',
    },
    body: jsonEncode({
      'app_id': oneSignalAppId,
      'include_player_ids': adminPlayerIds,
      'headings': {'en': '🚨 All API Keys Failed!'},
      'contents': {'en': '$_affectedUsersCount users affected. All $_totalKeys keys failed. Please add new keys.'},
      'priority': 10,
    }),
  );
}
```

---

## 8. Error Logging — Batch Strategy

### 8.1 Local Queue Flow

```
Error occurs
    → Add to in-memory queue
    → Persist to Hive (backup, survives app restart)
    → Check: queue.length >= 20 OR lastBatchWrite > 30s ago?
        → Yes: Firestore batch write (all at once)
        → No: Wait
```

### 8.2 Firestore Batch Write

```dart
Future<void> _flushErrorQueue() async {
  if (_errorQueue.isEmpty) return;
  
  final batch = FirebaseFirestore.instance.batch();
  
  for (final error in _errorQueue) {
    final docRef = FirebaseFirestore.instance
        .collection('api_error_logs')
        .doc();
    batch.set(docRef, error.toMap());
  }
  
  await batch.commit();
  _errorQueue.clear();
  _saveQueueToHive();
}
```

---

## 9. Migration Path

### 9.1 No Breaking Changes

The existing BYOK (bring-your-own-key) system remains intact. The migration:

| Phase | What Happens | User Experience |
|-------|-------------|----------------|
| 1: ApiKeyManager deployed | New service added, not active yet | Users still use their own keys |
| 2: Admin panel live | Admin can add keys, but feature-gated | No visible change |
| 3: Feature toggle ON | ApiKeyManager activates | Users auto-switch to admin keys |
| 4: Optional BYOK fallback | Settings toggle for power users | "Use my own key" option available |

### 9.2 Firestore Config Feature Gate

```dart
// In admin_config_screen.dart — existing config
'apiKeyManager': _config!.featureToggles.apiKeyManager,
```

When `apiKeyManager` is `false` (default): AIService continues using user's own key.
When `apiKeyManager` is `true`: AIService uses ApiKeyManager.

---

## 10. Future Considerations

| Idea | When | Complexity |
|------|------|-----------|
| Usage analytics per key (dashboard charts) | Phase 2 | Low |
| Auto-disable unhealthy keys | Phase 2 | Low |
| Rate limit per-user (fair usage policy) | Phase 2 | Medium |
| Multiple OpenRouter accounts for higher free tier quota | Phase 2 | Low |
| Admin email notification (alternative to OneSignal) | Phase 2 | Low |

---

## 11. Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/services/api_key_manager.dart` | **CREATE** | Core service: key pool, round-robin, failover, error reporting |
| `lib/features/admin/screens/admin_api_keys_screen.dart` | **CREATE** | Admin panel: add/edit/delete API keys |
| `lib/features/admin/screens/admin_error_logs_screen.dart` | **CREATE** | Admin panel: error log viewer |
| `lib/models/admin_api_key.dart` | **CREATE** | Model class for AdminApiKey |
| `lib/models/api_error_log.dart` | **CREATE** | Model class for ApiErrorLog |
| `lib/services/ai_service.dart` | **MODIFY** | ~3 lines: use ApiKeyManager instead of Hive key |
| `lib/features/admin/screens/admin_config_screen.dart` | **MODIFY** | Add `apiKeyManager` feature toggle |
| `lib/models/config/app_config_model.dart` | **MODIFY** | Add `apiKeyManager` bool field |
| `lib/features/settings/screens/settings_screen.dart` | **MODIFY** | Add "Use My Own Key" toggle (optional) |
| `lib/features/admin/screens/admin_dashboard_screen.dart` | **MODIFY** | Add API Keys entry to dashboard menu |

---

## 12. Key Design Decisions Summary

| Decision | Choice | Reason |
|----------|--------|--------|
| Key storage | Firestore + Hive cache | Real-time admin control + zero-latency reads |
| Failover strategy | Round-robin + cooldown | Prevents all users hitting same key |
| Error reporting | Batch write (20/30s) | Minimizes Firestore writes |
| Admin notification | OneSignal (debounced 5min) | Single admin alert, no spam |
| BYOK support | Optional toggle backwards-compatible | Existing users unaffected |
| Concurrent scale | 1000+ users | Hive cache + snapshot listener = minimal Firestore reads |
