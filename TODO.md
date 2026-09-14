# ⚔️ SpeakEasy Battle Arena (1v1 Live English Duel)

## 📌 Project Overview
**Battle Arena** is a real-time, gamified 1v1 English quiz competition feature for SpeakEasy. Users can challenge live online players or play quick matches with an intelligent AI Bot when no opponent is found within 6 seconds.

---

## 🚀 Key Feature Specifications

### 1. 🟢 Live Online Players List & Presence
- [x] **Firestore Presence System:** Tracks online status (`isOnline: true`, `lastActive: Timestamp`, `trophies`).
- [x] **Live Lobby Display:** Real-time stream of online users with glowing green indicators (🟢).
- [x] **Direct 1v1 Challenge:** "⚔️ Challenge" button next to each online player with instant accept/reject notifications.

### 2. ⚡ Smart Matchmaking & Bot Engine
- [x] **Radar Matchmaking:** 6-second radar search with animated pulsating waves.
- [x] **Smart AI Bot Fallback:** If no real player is found within 6 seconds, automatically pairs with an intelligent AI Bot.
- [x] **Human-like Bot Behavior:** Realistic Bengali/English names, custom avatars, realistic answer delays (2.5s – 5.5s), and ~75% accuracy rate.

### 3. 🎯 5-Question Match Composition (Curated Question Bank)
- [x] **2x Vocabulary Questions:** Word meanings, synonyms, and antonyms with Bengali translations.
- [x] **2x Grammar Questions:** Tense, prepositions, subject-verb agreement, conditionals.
- [x] **1x Spoken / Conversation Question:** Everyday spoken English scenarios (final speed round).
- [x] **Speed Bonus System:** Base 100 points + up to 50 points speed bonus for answering within 15 seconds.

### 4. 🚨 Forfeit & Disconnect Handling (Surrender Rule)
- [x] **Forfeit Protection:** If a player exits the match or disconnects before completion, they forfeit immediately.
- [x] **Opponent Victory:** The remaining opponent is instantly declared the **WINNER** and receives full victory trophies (+25 🏆).
- [x] **Exit Confirmation Dialog:** Clear warning modal alerting the player that leaving results in immediate forfeiture.

### 5. 🏆 Trophies, Leagues & Progression
- [x] **Trophy Economy:** Win = +25 Trophies 🏆, Loss = -10 Trophies.
- [x] **Arena Divisions:**
  - 🥉 **Novice Arena** (0 – 299 Trophies)
  - 🥈 **Challenger Arena** (300 – 799 Trophies)
  - 🥇 **Master Arena** (800 – 1499 Trophies)
  - 💎 **Grandmaster Arena** (1500+ Trophies)
- [x] **Local & Cloud Persistence:** Battle stats cached via Hive and synced with Firestore.

### 6. 💬 Live In-Match Emotes
- [x] **Quick Emotes:** 🔥, 😎, 👏, 🤯, ⚡ sent during battle.
- [x] **Floating Emote Bubbles:** Rendered in real-time above the player's avatar.

### 7. 🏠 Home Screen Integration
- [x] **Battle Arena Hero Card:** Placed directly below the Daily Quiz section on the Home Screen.
- [x] **Live Status & CTA:** Displays current trophy rank, division badge, and quick "Enter Arena ⚔️" navigation.

### 8. 🕐 Recently Active Warriors & Async Challenges (Phase 1+2)
*Players who don't come daily but play occasionally are no longer invisible.*
- [x] **Recently Active Lobby Section:** Offline warriors active within the last 7 days, sorted by trophies, with "Xh/Xd ago" last-seen badges (purple theme, grey offline dot).
- [x] **No-Index Query Design:** Single `orderBy lastActive desc limit 80` presence query filtered client-side — genuinely online players (heartbeat fresh ≤ 3 min) stay exclusive to the ONLINE LEARNERS list; stale "online" flags (app killed) are treated as offline.
- [x] **Async Challenges (`type: 'async'`):** Challenge an offline player — the challenge stays `pending` for up to **48h** and is delivered the moment they open the app (popup via GlobalBattleChallengeGate) plus a OneSignal push (3-day TTL, already sent on create).
- [x] **Async Challenge UX:** Incoming sheet shows a "🕐 Sent Xh ago — while you were offline" badge; lobby snackbar confirms delivery timing.
- [x] **Live-Recall on Accept:** When the (previously offline) receiver accepts, a new `onBattleChallengeUpdate` Cloud Function pushes the challenger — *"X accepted your challenge — join now!"* — and the challenger's outgoing-challenge listener auto-joins the room on next app open.
- [x] **Cleanup Policy Update:** pending challenges expire in 90s (live) / 48h (async); accepted-but-never-joined challenges swept after 2h (previously never cleaned).

### 9. 🛡️ Arena Hardening Pass (race, timers, trophies, presence, bots)
- [x] **Matchmaking race fixed:** queue candidates are claimed inside `runTransaction` with a `status == 'waiting'` precondition; room creation is inside the same transaction, so two searchers can never claim the same waiting player (no more duplicate/orphan rooms). Losers of the contention retry the next candidate.
- [x] **Queue wait 6s → 9s** so slow networks don't fall through to the bot while a human match is joining.
- [x] **Server-authoritative trophies:** new `BattleGameService.syncStatsFromServer()` adopts presence trophies/lossStreak into Hive — called when arena stats load and re-synced ~5s after every online match/forfeit, so the local preview converges with the Cloud Function's award (no drift, no stale overwrite via lobby heartbeat).
- [x] **Presence staleness:** heartbeat 45s → 20s; `BattlePresenceService` is now a `WidgetsBindingObserver` — app backgrounded/killed flips `isOnline=false` instantly (no 3-minute ghost); resume restores it.
- [x] **Auto-forfeit:** server threshold 4min → **90s**, schedule 5min → **every minute** (with 20s heartbeats, 90s silence ≈ 4-5 missed beats = genuinely disconnected).
- [x] **Authoritative round timer:** countdown is derived from a wall-clock round deadline (`_roundEndsAt`) instead of decrementing a counter — app pauses/throttling no longer desync local vs opponent time.
- [x] **Question pool:** category-bucketed cache (O(1) picks), AssetManifest parsed once instead of 3×, 5-minute TTL.
- [x] **Bot fairness:** trophies ±15 (was ±30), linear accuracy `0.55 + trophies/3000` capped at 0.92 (was step function), reaction time scales with the question's own time limit.
- [x] **Emote throttling:** 2s client cooldown (was unlimited Firestore writes per tap).
- [x] **Stream cost:** recently-active query now filters server-side (`lastActive > cutoff`, single-field index) with `limit(30)` instead of pulling 80 docs to every client.

### 10. 🔁 Rematch + 🤝 Friends Leaderboard
- [x] **Rematch button** on the post-match result screen (real players only): sends an async challenge flagged `isRematch` — the opponent gets "🔁 REMATCH REQUESTED!" popup instantly if still in the app, or on their next visit if they left. One send per result screen, button flips to "REMATCH SENT ✓".
- [x] **Friends Leaderboard tab** in Battle Stats: me + my friends ranked by trophies within the circle — one batched `getAll` of leaderboard docs (doc id == userId), seeded from friendship snapshots for friends without ranked history. Green "YOUR RANK AMONG FRIENDS" hero card, podium, YOU-highlighted rows; pull-to-refresh aware.

### 11. 🤝 Friends & Online Alerts (Phase 3)
- [x] **Friend request dedup (spam fix):** request doc id is deterministic `req_{from}_{to}` — a repeat send targets the existing doc and the security rules reject it, so duplicate pending requests between the same pair are impossible. Button flips to "Requested" optimistically on tap (rapid taps can't fire multiple writes). `onFriendRequestCreate` deletes stacked legacy duplicates (keeps oldest); the scheduled cleanup sweeps any remaining piles.
- [x] **Friend Requests:** send from player cards (online + recently active), profile sheets & post-match result screen (real players only, bots excluded). State-aware button: ➕ Send → ⏳ Requested (tap cancels) → Accept incoming → ✓ Friends.
- [x] **Data Model:** `friend_requests/{id}` (pending/accepted) + `friendships/{userId}` per-user friends map with snapshot data (name, photo, trophies, addedAt).
- [x] **Secure Mutual Write:** clients only write their own friendship doc; accepting flips request status and the `onFriendRequestUpdate` Cloud Function writes BOTH sides + pushes the requester "X accepted your request! 🎉".
- [x] **Requests Inbox:** `FriendRequestsScreen` with Accept/Decline, opened from the MY FRIENDS header chip (red badge with unread count); push on incoming request.
- [x] **MY FRIENDS Lobby Section:** friends list with live presence dots (green/amber/grey), ONLINE/IN BATTLE/OFFLINE badges, one-tap Duel (live challenge when online, async when offline), long-press to remove.
- [x] **Friend-Online Alert:** `onBattlePresenceOnline` fires only on the `isOnline` false→true presence transition (heartbeats never retrigger), pushes ALL friends in a single OneSignal call — "🟢 X is online! Challenge them ⚔️" (every login, per product decision).
- [x] **Cleanup:** accepted friend requests swept after 24h; stale pending requests after 7 days.
- [x] **Rules & Indexes:** friend_requests read/create/update/delete rules (receiver-only accept), owner-only friendships, composite index `(toUserId, status)`.

### 12. 🛡️ Seed Rooms + Anti-Cheat + Polish Batch
- [x] **Seed rooms (questions out of the room doc):** room docs now store only `questionSeed` + `questionCount` + `questionSetVersion`. Both clients regenerate the identical 5-question set locally via `BattleGameService.generateSeededQuestions(seed)` — every pool build step is deterministic (fixed-seed distractor/option shuffles, stable asset order). Tiny snapshots, cheaper reads, and correct answers never touch Firestore. Legacy embedded-question rooms still parse & play.
- [x] **Server-side answer verification:** the room creator writes `battle_answer_keys/{roomId}` (answers + timeLimits) into an admin-only collection right after the room transaction commits. Security rules: players may CREATE for their own room only, and can NEVER read/update/delete the key. `onBattleRoomWrite` now verifies every reported score against the key (`computeLegitScoreFromAnswers`) and clamps hacked scores before trophies are awarded; missing key → hard score cap fallback. Keys cleaned after 24h.
- [x] **Rules hardening:** battle_rooms create accepts questions-list OR questionSeed; new `battleSeedUnchanged()` makes seed/count/version immutable after creation (no mid-game seed swapping).
- [x] **Heartbeat optimization:** presence heartbeat is now stopped when the Battle Lobby leaves the nav stack (`dispose` → `stopPresenceHeartbeat`). During duels the arena route sits on top of the lobby, so the lobby stays mounted and auto-forfeit keeps working. No more 20s heartbeat writes from Home/Quiz/etc.
- [x] **Challenge rate-limit/dedup:** challenge doc id is deterministic `ch_{from}_{to}` with `set()` — at most ONE pending challenge per pair; repeat sends hit the existing doc and rules reject them (friendly snackbars on lobby, friend list & rematch button). Cleanup also dedups Quick Match queue entries per user (keeps newest).
- [x] **Sounds + haptics:** battles now use the app's existing `SoundService` (respects the user's mute/volume setting): correct → `game_correct`, wrong/timeout → `game_wrong`, win/forfeit-win → `game_achievement` (+heavy haptic), draw → `game_level_up`, loss → `game_over`, emote send → `game_button_tap` (+selection haptic). Haptics via `HapticFeedback` (no new dependency).

### 13. 📝 Daily Quiz — MCQ-only + Question Bank Expansion
- [x] **Removed unused question types:** fill_blanks / match_pairs / sentence_rearrange code deleted (3 widgets, QuestionType enum, MatchPair model, pairs/jumbledWords/responseData fields, complex-answer handlers, review-screen branches, "2 new-type per day" generation logic). Everything is now plain MCQ — the whole feature is simpler and the play screen renders one path only.
- [x] **+36 new questions (234 → 270):** 12 vocabulary, 12 grammar, 12 conversation (dq_244–dq_279), bilingual Bangla/English with explanations; difficulty spread kept balanced (easy/medium/hard). Category badge on the quiz header now shows 📖 Vocabulary / 📝 Grammar / 💬 Conversation correctly.

### 14. 🏟️ Room-First Challenges + Challenge Popup Fix
- [x] **Room-first flow:** challenging someone now creates a WAITING room at SEND time (seed questions + answer key prepared up-front); the challenge doc carries the roomId. Accepting JOINS the room; the HOST presses **START BATTLE** to begin — no more surprise instant-duels. New `BattleWaitingRoomScreen` (player cards, join/ready states, START / Cancel / Leave, back-button cleanup, PopScope).
- [x] **Restore everywhere:** gate routes accepted outgoing challenges to the waiting room (host side, covers async + app restarts); accepted incoming restores the guest seat; in_progress rooms still drop straight into the arena (incl. legacy senders without roomId, which keep the old immediate-start path).
- [x] **Challenge popup fixed (was a dead end):** sheet no longer one-shot-blocked — pending challenges resurface until answered; buttons await with retryable errors; new **Later** button; lobby shows a persistent "Respond" banner for postponed challenges (`reshowChallengeProvider`).
- [x] **Decline/cancel cleanup:** receiver's decline deletes the waiting room immediately (participants may delete rooms while status == 'waiting'); host cancel deletes room + challenge; guest leave marks `player2LeftAt` so the host is notified. Cleanup sweeps waiting rooms > 48h.
- [x] **Models/rules:** BattleRoom gains `player2JoinedAt`/`player2LeftAt`; room delete rule extended for waiting rooms; challenge doc gains `roomId` at creation.

---

## 📁 File Structure
```
lib/features/battle_arena/
├── models/
│   └── battle_models.dart
├── services/
│   ├── battle_presence_service.dart
│   ├── battle_bot_simulator.dart
│   ├── battle_game_service.dart
│   └── battle_matchmaking_service.dart
├── providers/
│   ├── battle_arena_provider.dart
│   └── battle_presence_provider.dart
├── widgets/
│   ├── live_player_card.dart
│   ├── battle_timer_bar.dart
│   ├── battle_emote_overlay.dart
│   └── radar_search_dialog.dart
└── screens/
    ├── battle_lobby_screen.dart
    ├── battle_arena_screen.dart
    ├── battle_waiting_room_screen.dart
    ├── battle_result_screen.dart
    └── battle_leaderboard_screen.dart
```
