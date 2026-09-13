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

### 9. 🤝 Friends & Online Alerts (Phase 3 — upcoming)
- [ ] Friend requests from player cards, leaderboard & post-match screens.
- [ ] Friends section in lobby with live presence dots & one-tap challenge.
- [ ] "Friend is online now" OneSignal push (every login) via presence-transition Cloud Function.

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
    └── battle_result_screen.dart
```
