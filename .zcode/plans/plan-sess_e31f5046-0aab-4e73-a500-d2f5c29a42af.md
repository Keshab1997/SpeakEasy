## Configurable cooldowns (admin-provider tuning)

### Problem
Cooldown durations hardcoded (`429→60s`, `500→120s`, default `30s`) — admin-কে code ছাড়া tune করতে দিতে হবে (যেমন OpenRouter-এর rate-limit cooldown আলাদা হতে পারে)।

### Design

**১. `admin_key_group.dart`** — ৩টা optional field:
- `rateLimitCooldownSeconds` (429), `serverErrorCooldownSeconds` (5xx), `defaultCooldownSeconds` (অন্য)
- null = built-in default। fromMap/toMap/copyWith update

**২. `api_key_manager.dart`**:
- `_getCooldownDuration(statusCode, provider)` — key-র provider group config থেকে seconds পড়বে, null হলে existing hardcoded default
- `reportFailure` → `key.provider` pass
- 401/403 সবসময় 365 দিন (auth error — configurable না, সেটাই ঠিক)

**৩. Admin screen** — group header-এ settings ⚙️ icon → bottom sheet dialog:
- ৩টা number field (Rate-limit / Server error / Default, সেকেন্ডে) — groupData থেকে prefill, খালি = default
- Save → `_saveGroupConfig`-এ optional cooldown fields

**৪. `firestore.rules`** — `admin_key_groups` update rule-এ `onlyKeysAffected([...])` list-এ ৩টা নতুন field add (redeploy লাগবে — updated block দেব)

**৫. Test** — নতুন `test/admin_key_group_test.dart`: fromMap/toMap/copyWith round-trip cooldown fields-সহ

### Files
- `lib/models/admin_key_group.dart`
- `lib/services/api_key_manager.dart`
- `lib/features/admin/screens/admin_api_keys_screen.dart`
- `firestore.rules`
- `test/admin_key_group_test.dart` (new)

### Verification
- `flutter analyze` + `flutter test`
- Rules redeploy (updated `admin_key_groups` block — দিয়ে দেব)