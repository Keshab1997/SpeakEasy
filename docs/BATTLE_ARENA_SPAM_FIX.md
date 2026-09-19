# 🛡️ Battle Arena — Challenge Spam Fix (Sothik Niyom)

**Date:** 2026-09-19  
**Issue:** `Battle Arena te challenge jkhn kora hy akta player ke akadhik bar challenge kora jai aki somay tarpor user akta request accept korle tkhn room e add hy na por por request astey thake`

## 🔍 Root Cause Analysis

### 1. Spam Challenge to Same Player (Aki Somay Akadhik Bar)
- `BattlePresenceService.sendChallenge()` used deterministic ID `ch_{from}_{to}` with **delete-then-create** — every tap deleted the previous doc and created a new one with a new `roomId`.
- `BattleLobbyScreen._sendChallenge()` created a **new waiting room BEFORE** checking for existing pending challenges — spamming 3 taps = 3 rooms, but only the last `roomId` survived in Firestore. The other 2 became **orphan rooms**.
- `_challengingUserId` only blocked the exact same `userId` during the `await`, but rapid double-taps within milliseconds bypassed it (concurrent executions).
- No cooldown, no pending-check, no `isInBattle` guard at service level — UI disabled `isInBattle` but a race could still send.

### 2. Accept Kore Room e Add Hoy Na
- `GlobalBattleChallengeGate._onAccept()` strictly checked `isUserOnline()` (presence `isOnline:true` + `lastActive` ≤3min). Heartbeat is every 20s — network jitter or app backgrounded for 30s made a **live host appear offline**, so valid accepts were **blocked with snackbar**, leaving the challenge `pending` forever. The gate then kept re-showing the sheet → "por por request".
- If spam had already overwritten the challenge doc (sender's new `delete+create` after receiver's accept), the receiver's `accepted` doc was **deleted and replaced** with a new `pending`. Host's `streamChallenge` saw `null` → popped waiting room and deleted room. Guest tried to join a **deleted room** → `getRoom()` failed → "room no longer available" → challenge stayed pending → loop.
- `GlobalBattleChallengeGate._enterChallengeRoom()` was guarded by `_waitingRoomOpen || battleWaitingRoomOpen`, but host already in waiting room **stayed**, guest's join could silently fail without cleaning the `accepted` challenge — stuck in `accepted` but not in room.

### 3. Por Por Request Astey Thake (Sequential Popups)
- `incomingChallengesProvider` returns **all pending challenges** to the user (different senders or resent same sender). The gate shows the first pending, and after accept/decline, the next pending immediately surfaces. While in duel (`_arenaOpen` true) sheets are suppressed, but **after duel ends** all still-pending challenges resurface one-by-one.
- No auto-decline of other pending challenges after accepting one — the user had to manually decline each.

---

## ✅ Sothik Niyom — Fix Implementation

### 1. `BattlePresenceService` — Server-Side Spam Protection

**New exception:** `ChallengeBlockedException` with user-facing Bengali/English messages.

**A. In-memory cooldown (30s)**
```dart
static final Map<String, DateTime> _lastChallengeSentAt = {};
if (lastSent != null && now.difference(lastSent).inSeconds < 30) throw ChallengeBlockedException(cooldownMsg);
```

**B. Outgoing pending limit (max 3)**
- A single sender cannot have ≥3 pending challenges at once (prevents spamming whole lobby).

**C. Receiver `isInBattle` guard**
- Fetches `battle_presence/{toUserId}` — if `isInBattle:true` and fresh (<3min), blocks with "Player is busy in a duel ⚔️".

**D. Existing challenge age check (blocks resend while pending/accepted)**
- If existing doc `status == 'pending'` and age < 60s (live) / 120s (async) → block: "Already challenged — waiting for reply ⏳ (Xs wait)".
- If `status == 'accepted'` → checks `battle_rooms/{roomId}` status; if `waiting` or `in_progress`, blocks: "Duel already accepted — join the waiting room".
- Only after cooldown/expiry does it `delete()` old doc and call `onSupersededRoom(oldRoomId)` to delete orphan room.

**E. Proper orphan cleanup**
- `onSupersededRoom` callback lets `BattleLobbyScreen` delete the previous room instantly.

### 2. `BattleLobbyScreen` — Client-Side Guards

**A. Concurrency guard**
```dart
if (_challengingUserId != null) return snackbar "Please wait…";
```

**B. Pending-check before room creation**
```dart
bool _hasPendingTo(String toId) => outgoing.any(c.toUserId==toId && status==pending);
if (_hasPendingTo(toId)) return snackbar "Already challenged — waiting for reply";
```
- Prevents creating a new room when a pending already exists — no orphan rooms.

**C. `onSupersededRoom` integration**
- When service replaces an old (expired) challenge, the old room is deleted immediately.

**D. Reactive UI**
- `ref.watch(outgoingChallengesProvider)` → `outgoingPendingIds` Set.
- `LivePlayerCard`, `RecentPlayerCard`, `FriendListCard` now show **"Pending ⏳"** (amber, disabled) instead of "Duel" when pending, so spamming is visually blocked.
- `ref.watch` inside `build` + helper methods `_buildFriendsSection` / `_buildRecentlyActiveSection` ensures buttons disable **instantly** across whole lobby.

**E. Error handling**
- Catches `ChallengeBlockedException` separately and shows its message (cooldown/pending/busy) in amber snackbar.

### 3. `GlobalBattleChallengeGate` — Reliable Accept & No Spam Loop

**A. Soft online check with room fallback**
```dart
bool senderOnline = await presence.isUserOnline(fromUserId);
if (!senderOnline && challenge.roomId != null) {
  final fallbackRoom = await matchmaking.getRoom(challenge.roomId!);
  if (fallbackRoom.status == waiting) senderOnline = true;
}
```
- Fixes false-negative "offline" blocks due to heartbeat jitter.

**B. Auto-decline other pending challenges**
```dart
Future<void> _declineOtherPendingChallenges({required String keepId}) async {
  final incoming = ref.read(incomingChallengesProvider).asData?.value ?? [];
  for (final c in incoming.where((c)=>c.id != keepId)) {
    await presence.respondToChallenge(c.id, false);
    if (c.roomId != null) deleteRoom(c.roomId);
  }
}
```
- Called after successful accept (both room-first and legacy flows) — stops "por por request" spam. The accepted duel proceeds, others are auto-rejected.

**C. Robust room join**
- `_enterChallengeRoom` already retries `getRoom` once (800ms) and shows snackbar on failure. Now also cleans up if room not found.

### 4. `BattleResultScreen` — Rematch Spam Fix
- Added `on ChallengeBlockedException` catch to rematch flow — shows cooldown message instead of generic failure. `_rematchSent` flag already prevents double-send per result screen, now also protected by service-level cooldown.

### 5. `LivePlayerCard` / `RecentPlayerCard` / `FriendListCard` — UX
- Changed `Sent...` → `Pending ⏳` for clarity.

---

## 🧪 Sothik Niyom Summary (User-Facing Rules)

| Niyom | Details |
|-------|---------|
| **1. Ekjon ke ekbar** | Same sender → same receiver: 1 pending max. Next challenge blocked for 60s (live) / 120s (async) until receiver replies. |
| **2. Cool-down 30s** | Same pair cannot be re-challenged within 30s even if previous was declined (in-memory). |
| **3. Max 3 pending** | One player cannot have more than 3 outgoing pending challenges at once (lobby-wide spam protection). |
| **4. Busy check** | `isInBattle:true` players show "Busy" and cannot be challenged (service also blocks). |
| **5. Offline fallback** | Accept is allowed if room is still `waiting` even if presence appears offline (fixes ghost offline false positives). |
| **6. Auto-cleanup** | Accepting one challenge auto-declines all other pending incoming challenges — no sequential popups. |
| **7. Orphan free** | Expired pending's room is deleted instantly when replaced, no ghost rooms. |
| **8. Visual feedback** | Pending button shows "Pending ⏳" disabled; concurrent taps show "Please wait…" snack. |

---

## 🔧 Files Changed

- `lib/features/battle_arena/services/battle_presence_service.dart` — added `ChallengeBlockedException`, cooldown maps, outgoing limit, receiver busy check, age-based pending/accepted blocking, `onSupersededRoom` handling.
- `lib/features/battle_arena/screens/battle_lobby_screen.dart` — added `_hasPendingTo`, concurrency guard, pending-check before room creation, `onSupersededRoom` cleanup, reactive `outgoingPendingIds` watch, pending UI, `ChallengeBlockedException` handling.
- `lib/features/battle_arena/widgets/global_battle_challenge_gate.dart` — soft online check with room fallback, `_declineOtherPendingChallenges`, called after accept.
- `lib/features/battle_arena/screens/battle_result_screen.dart` — added `ChallengeBlockedException` handling for rematch.
- `lib/features/battle_arena/widgets/live_player_card.dart` — label `Sent...` → `Pending ⏳`.
- `lib/features/battle_arena/widgets/recent_player_card.dart` — same.
- `lib/features/friends/widgets/friend_list_card.dart` — same.

---

## ✅ Result

- Spam tap → second tap shows "Already challenged — waiting for reply ⏳" and no new room.
- Accept → reliably joins waiting room (room fallback prevents false offline block), other pending auto-declined, no repeated popups.
- Busy players cannot be spammed.
- No orphan rooms leak.

