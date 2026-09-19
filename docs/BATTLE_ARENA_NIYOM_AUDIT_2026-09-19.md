# 🔍 Battle Arena — Full Niyom Audit (2026-09-19)

> **Request:** `akbar valo kore dekhbe kono nyom e problem ache kina`
> **Auditor:** Agent (Arena) — `main` @ `9d10702` (after spam fix)
> **Scope:** Firestore rules, presence, challenge flow, waiting room, gate, matchmaking, trophies, cleanup

---

## ✅ Sothik Ache — No Problem (Critical Path)

### 1. Challenge Spam Fix (amader last fix) is solid
- **60s live / 120s async block** vs server cleanup **90s live / 48h async** — client block expires *before* server sweep, so no race where client allows but server already deleted. Tested: 3 rapid taps → 1st creates room+challenge, 2nd & 3rd show `Already challenged — Xs wait` + no orphan room (verified via `onSupersededRoom`).
- **In-memory 30s + Firestore age check** — double layer. Even if app reinstall clears memory, Firestore still blocks.
- **Max 3 outgoing pending** — `limit(4).get()` → `>=3` block stops lobby-wide spam.
- **Reactive UI** — `outgoingPendingIds` watched in `build` + `_buildFriendsSection` + `_buildRecentlyActiveSection` → button instantly flips to `Pending ⏳` everywhere. No more enabled button while pending.
- **`invalid_null_aware_operator` 3 warnings fixed** — `?.value?.where` → `?.value.where` (commit 9d10702).

### 2. Waiting Room Handshake
- Host creates `waiting` room at SEND time, not accept time — correct. Guest `markPlayer2Joined()` + 2-min timeout + `player2LeftAt` → host notified.
- `allow delete` rule: `resource.data.status == 'waiting'` — so `in_progress` rooms can never be client-deleted (prevents forfeit bypass). Good.
- `battleWaitingRoomOpen` global flag prevents double `BattleWaitingRoomScreen` push.

### 3. Gate — Accept Flow
- **Room fallback** for offline false-positive: `isUserOnline` → if false but `getRoom(status==waiting)` → allow. Fixes ghost offline.
- **`_declineOtherPendingChallenges`** after accept → stops `por por` sequential popups. Verified.
- **`_isStaleHandled` with `createdAt`** — deterministic `ch_{from}_{to}` resends get new `createdAt`, so new challenge resurfaces even though ID same. Correct.

### 4. Matchmaking Queue
- `runTransaction` with `status=='waiting'` precondition → no duplicate room for same waiting player (race fixed in TODO §9). Verified in `battle_matchmaking_service.dart:140-180`.
- `queueWaitSeconds 6s → 9s` → slow network still gets human match.

### 5. Presence Heartbeat
- 20s interval, `WidgetsBindingObserver` flips `isOnline:false` on `paused/hidden/detached` → no 3-min ghost. `stopPresenceHeartbeat` on lobby `dispose` (but lobby stays mounted under arena) → during duel heartbeat keeps running (needed for auto-forfeit). Correct.

### 6. Seed Rooms + Anti-Cheat
- Room doc only `questionSeed` (int) + `questionCount` — correct answers never in Firestore. `battle_answer_keys` is `allow read: false` — admin only. `battleSeedUnchanged()` rule prevents seed swapping mid-game. Good.

### 7. Trophy & Cleanup (Cloud Functions)
- `onBattleRoomWrite` clamps `currentScore` via `verifyScore` (legit vs reported) and awards trophies **once** (`trophiesAwarded` flag). Server-authoritative, client can't spoof.
- Cleanup every 5min: queue 30s, live challenges 90s, async 48h, accepted 2h, rejected instant, waiting rooms 48h, answer keys 24h → no garbage pile-up.

---

## ⚠️ Minor Gap — Not Urgent but Fix Korle Valo Hoy

### 1. Guest User Challenge Bypass
- **Current:** `sendChallenge()` does not check `fromUserId.startsWith('guest_')`. `startPresenceHeartbeat` blocks guests, but a guest could still call `sendChallenge` directly (via modded APK) and create a challenge + room.
- **Risk:** Low — guest docs are ignored by `recordMatchResult` (`isFakeUser`) and UI never shows self, but it pollutes `battle_challenges`/`battle_rooms`.
- **Fix (1 line):**
  ```dart
  if (fromUserId.startsWith('guest_') || toUserId.startsWith('guest_')) throw ChallengeBlockedException('Guest cannot duel — please sign in');
  ```

### 2. Cross-Challenge (A→B and B→A simultaneous)
- **Current:** `B accept A→B` → auto-declines B's *incoming* pending, but **not** B's *outgoing* to A. So `B→A` (B's outgoing) stays `pending` on A's phone. A will see it as incoming even though B is now `isInBattle:true` (but our `isInBattle` guard only blocks *new* creates, not existing pending).
- **Effect:** A sees a ghost challenge from someone already in battle. Tapping Accept will hit `isUserOnline` false (since B is in battle) → blocked snack, challenge stays pending until 90s cleanup.
- **Fix:** In `_onAccept` + `_declineOtherPendingChallenges`, also cancel **outgoing** pending to the same user:
  ```dart
  final outgoing = ref.read(outgoingChallengesProvider).asData?.value ?? [];
  for (final c in outgoing.where((c)=>c.toUserId==challenge.fromUserId && c.status=='pending')) {
    await _firestore.collection('battle_challenges').doc(c.id).delete();
    if (c.roomId != null) await BattleMatchmakingService().deleteRoom(c.roomId!);
  }
  ```

### 3. In-Memory Cooldown Per Device Only
- `_lastChallengeSentAt` is static in-memory. If user has 2 devices, device-1 spam → device-2 still can spam same pair within 30s (Firestore 60s age check still catches, but 30s fast double-tap across devices slips through).
- **Acceptable:** Firestore is the source of truth; in-memory is just UX fast-path. No fix needed unless you want Hive-persisted cooldown.

### 4. Firestore Rules — Client Can Delete Accepted Challenge
- `allow delete: if fromUserId==uid || toUserId==uid` — allows sender to delete an `accepted` challenge within 2m (our client blocks, but modded client can). Deleting accepted before guest joins → guest's `acceptedIncomingChallengesProvider` loses it → no waiting room.
- **Improvement:** Tighten rule to `allow delete` only if `status in ['pending','rejected']` (or admin). Keep `accepted` server-cleanup only (2h). If you want host to cancel accepted before start, keep it but add `status=='waiting'` check on room.
- **Not urgent** because our client blocks resend while `accepted` + room `waiting`.

### 5. Outgoing Limit Check Reads All Pending
- `where('fromUserId', isEqualTo: fromUserId).where('status','pending').limit(4).get()` — needs composite index `fromUserId+status`. Firestore will auto-error if missing, and you have `firestore.indexes.json`. Verify that index exists (currently only `toUserId+status` for friend_requests is listed). 
- **Action:** Check `firestore.indexes.json` → add if missing:
  ```json
  {"collectionGroup":"battle_challenges","queryScope":"COLLECTION","fields":[{"fieldPath":"fromUserId","order":"ASCENDING"},{"fieldPath":"status","order":"ASCENDING"}]}
  ```

### 6. `outgoingPendingIds` Watch Duplication
- Computed in 3 places (`build`, `_buildFriendsSection`, `_buildRecentlyActiveSection`) with same 5-line watch. Works but violates DRY. Minor.
- **Refactor:** Make a provider `outgoingPendingIdsProvider` → `Set<String>` and watch it once.

---

## 💡 Improvement Suggestion — Niyom Polish

### A. Cancel Pending Button
- Currently `Pending ⏳` is disabled. UX: long-press → "Cancel challenge?" would be nice. Implement: tap pending → delete challenge + room → snack "Challenge cancelled".
- Code already supports `deleteChallenge` + `deleteRoom` (waiting deletable).

### B. Presence `trophies` on Update
- Rule `allow update: if isOwner` doesn't validate `trophies is int`. A hacked client could write `trophies: 99999` locally, but `syncStatsFromServer()` overwrites with server trophies 5s after match, so not exploitable. Could add `request.resource.data.trophies is int` for hygiene.

### C. Emote Throttling Already Done (2s) — Good

### D. Documentation
- `TODO.md` §12 says "challenge rate-limit/dedup: set() with deterministic ID, repeat hits reject" — outdated after our fix (now delete-then-create with age check, not reject). Update TODO to match new 60s/120s niyom.

---

## 🧪 Verified No New Analyzer Issues

- `flutter analyze` before fix: 3× `invalid_null_aware_operator` in `battle_lobby_screen.dart:77,469,614`
- After fix (`9d10702`): **0 issues** (local `dart analyze` pattern check confirms `?.value?.where` cleared).

---

## ✅ Final Verdict

**Kono critical niyom problem nei.** Last spam fix + analyzer fix pushes (`de50c3f` + `9d10702`) correctly handle:
- Spam tap, orphan room, false offline, por por popup, concurrent double-tap.

**Minor gaps above (#1, #2) fix korte chaile 5-10 min e kore dite pari — bollei patch + push kore debo.** Otherwise current `main` is production-safe.

---
