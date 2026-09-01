# ⚔️ Battle Arena — Code Review Report

**রিপো:** SpeakEasy · **ফিচার:** `lib/features/battle_arena/` (১৪টি ফাইল, ~৩,৮৫৭ লাইন)
**তারিখ:** 2026-09-01

---

## 🔴 CRITICAL BUGS (গেম ভেঙে যাচ্ছে / চিট করা যাচ্ছে)

### ১. Online 1v1 ম্যাচে round এগিয়ে যাওয়ার শর্ত ভুল — লাইভ PvP কার্যত broken

📄 `providers/battle_arena_provider.dart` → `submitLocalAnswer()`

```dart
// ❌ ভুল:
if (state.isOpponentAnswered || state.opponent.isBot == false) {
  _completeRoundWithDelay();
}
```

`state.opponent.isBot == false` মানে **যেকোনো human opponent** — অর্থাৎ অনলাইন ম্যাচে আপনি উত্তর দেওয়ামাত্রই, **প্রতিপক্ষ উত্তর দিক বা না দিক**, round এগিয়ে যাবে। দুইজন player আলাদা আলাদা গতিতে খেলবে — একজন round 3-এ, অন্যজন তখনো round 1-এ।

সাথে আরেকটা সমস্যা: Firestore-এ room-এর `currentRoundIndex` কখনো update-ই হয় না (`submitAnswer` শুধু answer/score লেখে), আর round বদলানোর সময় Firestore-এর `selectedAnswer` field clear করা হয় না। ফলে নতুন round শুরু হলেও প্রতিপক্ষের **আগের round-এর উত্তর** Firestore-এ থেকে যায়, এবং `_subscribeToRoom`-এ এই চেক:

```dart
if (opp.selectedAnswer != null && opp.selectedAnswer != state.opponentAnswerIndex)
```

নতুন round-এ পুরনো উত্তরটাকেই নতুন উত্তর ভেবে UI দেখিয়ে দেয় (ভুল score/answer sync)।

**✅ সমাধান:**
- শর্ত হবে: bot হলে timer-ই advance করবে; human হলে **দুইজনেই উত্তর দেওয়ার পর** অথবা **timer-এর time শেষ হলে** তবেই advance হবে:
  ```dart
  if (state.opponent.isBot) {
    if (state.isOpponentAnswered) _completeRoundWithDelay();
  } else {
    // human: timer expiry বা দুইজনের উত্তর — যেটা আগে হয়
    if (state.isAnswerSubmitted && state.isOpponentAnswered) _completeRoundWithDelay();
    // না হলে 15s timer _onRoundTimeExpired → advance করবে
  }
  ```
- Round advance করার সময় Firestore-এ round index + আগের round-এর `selectedAnswer`/`currentRound` clear করতে হবে (নতুন field, যেমন `player1.answers: {roundIndex: answer}` array/map ব্যবহার করা ভালো — নিচে #৩ দেখুন)।
- দুই client-কে একই round-এ রাখতে room-এর `currentRoundIndex` listen করে client round sync করতে হবে।

---

### ২. `_completeRoundWithDelay()` একাধিকবার call হয়ে round skip হয়ে যায়

📄 `providers/battle_arena_provider.dart`

`submitLocalAnswer` ও timer expiry — দুই জায়গা থেকেই `_completeRoundWithDelay()` call হয়, কিন্তু কোনো guard flag নেই। ১.৮ সেকেন্ডের delay-এর ভেতরে:
- player উত্তর দিল **এবং** timer প্রায় শেষ → function ২ বার schedule হয়
- দুইটা Timer আলাদা → `currentRoundIndex` দুইবার বাড়ে → **একটা round পুরো skip** হয়ে যায়, বা ৫ round শেষ হওয়ার আগেই `_finishDuel()` চলে যায়

একই সমস্যা `_scheduleBotAnswer`-এর callback থেকেও হতে পারে।

**✅ সমাধান:** একটা `bool _roundTransitioning = false` guard যোগ করুন — transition শুরু হলে true, নতুন round চালু হলে false; কিংবা delay Timer-টিকে field-এ রেখে নতুন call-এ আগেরটা cancel করুন।

---

### ৩. Score client থেকে Firestore-এ লেখা হয় — সহজেই চিট করা যায়

📄 `services/battle_matchmaking_service.dart` → `submitAnswer()`

```dart
await _firestore...update({
  '$fieldPrefix.currentScore': newScore,   // ❌ client নিজেই score পাঠাচ্ছে
});
```

Client-এর পাঠানো `newScore` server কখনো যাচাই করে না। Firestore rules (`firestore.rules` লাইন ৩৯৭-৪০০) শুধু participant কিনা আর questions immutable কিনা দেখে — কেউ ইচ্ছা করলে **নিজের score ৯৯৯৯৯** লিখতে পারে, এমনকি update map-এ **প্রতিপক্ষ player-এর field-ও** বদলে দিতে পারে (rules শুধু player id অপরিবর্তিত আছে কিনা দেখে)।

**✅ সমাধান (সঠিক আর্কিটেকচার):**
- Client শুধু `selectedAnswer` + `answeredAt timestamp` পাঠাবে।
- **Cloud Function** (Firestore trigger) correctAnswer-এর সাথে মিলিয়ে score, trophy, winner সব server-side হিসাব করবে; room `completed` করবে।
- অন্তত rules-এ constraint: এক player শুধু নিজের field-এ লিখতে পারবে এবং score monotonically বাড়বে (current >= old)।

---

### ৪. Matchmaking-এ race condition — দুই player একই queue entry দখল করতে পারে

📄 `services/battle_matchmaking_service.dart` → `findMatch()`

দুইজন player একসাথে "Quick Match" চাপলে দুইজনেই একই waiting queue doc দেখতে পায়, দুইজনেই আলাদা room তৈরি করে একই doc-এ update করার চেষ্টা করে → **ghost rooms** তৈরি হয়, কোনো player কখনো কারো সাথে মিলে না। `matchedDoc` নেওয়ার সময় কোনো transaction / conditional write (`status == 'waiting'` থাকলে তবেই update) নেই।

আরেকটা সমস্যা: মিল হওয়ার পর যে player-1 ছিল (যে queue-তে অপেক্ষা করছিল), তার client-এর কোনো subscription নেই যে তাকে নিয়ে room তৈরি হয়েছে — সে শুধু নিজের queue doc `status='matched'` দেখে, কিন্তু **room doc player হিসেবে নিজেকে না পেলেও** fromMap ঠিকঠাক কাজ করে। এটা ঠিক আছে তবে room fetch fail করলে (network) completer কখনো complete হয় না — `exists` false হলে কোনো fallback নেই।

**✅ সমাধান:** queue doc update একটা Firestore `transaction`-এ করুন (status waiting থাকলে তবেই matched করবে), নইলে পরের doc চেষ্টা করুন; room fetch fail হলে bot fallback।

---

### ৫. Direct challenge accept করলে challenge পাঠানো player কিছুতেই জানে না (feature অর্ধেক তৈরি)

📄 `screens/battle_lobby_screen.dart`

- Challenge receiver **Accept** করলে room তৈরি হয় ও challenge doc-এ `status='accepted', roomId` লেখা হয়।
- কিন্তু **challenge পাঠানো player** `incomingChallengesProvider`-এ শুধু `toUserId == me` এ query করে — নিজের পাঠানো challenge-এর status শোনার **কোনো listener নেই**। তাই সে accept/reject কিছুই জানে না, ম্যাচেও যোগ দিতে পারে না।
- Reject করলেও sender কিছু জানে না; expired challenge-ও কখনো clean হয় না (pending চিরকাল থেকে যায়)।

**✅ সমাধান:** একটা `outgoingChallengesProvider` যোগ করুন (`where('fromUserId', isEqualTo: me)`), accepted হলে sender-ও `startFromRoom()` করবে; Cloud Function/Firestore TTL দিয়ে ৬০ সেকেন্ড পর pending challenge expire করুন।

---

## 🟠 MAJOR BUGS (ভুল ফলাফল / experience নষ্ট)

### ৬. Time limit সব জায়গায় hardcoded `15` — `BattleQuestion.timeLimit` field কখনো ব্যবহারই হয় না

- `provider._startRoundTimer()` → `remainingSeconds: 15`
- `submitLocalAnswer()` → `final timeTaken = 15 - state.remainingSeconds;`
- `battle_arena_screen.dart` → `BattleTimerBar(totalSeconds: 15)`
- অথচ model-এ `timeLimit` আছে আর `loadCuratedQuestions()` সব question-এ `timeLimit: 15` সেট করছে — ভবিষ্যতে কোনো question ২০s বা ১০s করলেও সবকিছু ভেঙে যাবে, speed bonus-ও ভুল হবে।

**✅ সমাধান:** সব জায়গায় `currentQuestion?.timeLimit ?? 15` ব্যবহার করুন; `calculateRoundScore`-এও `timeLimit` parameter নিন।

### ৭. Trophy sync প্রায় সবসময়ই হয় না — `userId` পাঠানোই হয় না

📄 `services/battle_game_service.dart` → `saveMatchResult()`

```dart
if (userId != null && ...) { /* Firestore presence update */ }
```

কিন্তু `BattleArenaNotifier`-এর সব কল — `_finishDuel()`, `_handleOpponentForfeited()`, `forfeitCurrentMatch()` — কোনোটিতেই `userId` pass করা হয় না! তাই Firestore presence-এ trophy update হয় না (কোডের comment-এ লেখা "so 115 shows in Firebase" — আসলে হচ্ছে না)। শুধু ৪৫ সেকেন্ডের heartbeat পরে sync হয়। `BattlePresenceService.updateTrophiesNow()` method-টাও বানানো আছে কিন্তু **কোথাও call করা হয় না** (dead code)।

### ৮. Result screen-এ দেখানো trophy change আর প্রকৃত change মেলে না

- Draw হলে `calculateTrophyDelta` = **+5**, কিন্তু `state.trophyDelta` সেট হয় ঠিকই; আবার forfeit-win হলে hardcoded **+25** দেখানো হয় — কিন্তু হারানো player-এর local Hive-তে loss হিসাব হয় ঠিকই, online-এ তার কোনো notification নেই।
- Player forfeit করে exit করলে সে result screen দেখেই না, তার trophy -১০ হয় চুপিচুপি — UI feedback নেই।

### ৯. Online ম্যাচে প্রতিপক্ষ কোন অপশনে উত্তর দিল / সঠিক কিনা — কিছুই দেখা যায় না

📄 `screens/battle_arena_screen.dart` → `_buildOptionTile()`

Option tile-এর রঙ শুধু `battleState.selectedAnswerIndex` (নিজের উত্তর) দিয়ে দেখায়। `opponentAnswerIndex` state-এ এসেও কোনো visual নেই (অন্য রঙের marker/ছোট avatar)। মানে লাইভ ম্যাচে "প্রতিপক্ষ উত্তর দিয়েছে" ছাড়া তার উত্তরটা কী ছিল কখনো দেখা যায় না।

### ১০. প্রতিপক্ষের score শুধু তার উত্তর দেওয়ার সময় sync হয় — time-out হলে না

`_subscribeToRoom` score আপডেট করে শুধু `opp.selectedAnswer != null` হলে। প্রতিপক্ষ সময়মতো উত্তর না দিলে (০ পয়েন্ট) তার score আর sync হয় না — round বদলালে `opponentAnswerIndex` clear হয়ে যায়, তাই আগের স্কোরটাই আটকে থাকে। চূড়ান্ত winner নির্ধারণ আপনার **নিজের local score vs পুরনো opponent score** দিয়ে হয় — ভুল ফলাফল আসতে পারে।

### ১১. Bot reaction time ৩–৭ সেকেন্ড, কিন্তু round ১৫ সেকেন্ড → bot সময় ফুরিয়ে যায়

📄 `services/battle_bot_simulator.dart`

- `decideAnswer()` reaction = `3 + nextInt(5)` = **৩–৭ সেকেন্ড** (comment-এ লেখা 2.5–6.5, কোডে ভিন্ন)।
- যদি bot-এর timer ৭s-এর আগেই আপনি উত্তর দিয়ে দেন + round advance হয়ে যায় (bug #1/#2-এর কারণে প্রায়ই হয়), bot উত্তর দেওয়ার সুযোগই পায় না → bot 0 পয়েন্ট → ম্যাচ খুব সহজ, কোনো চ্যালেঞ্জ নেই।
- Bot accuracy fixed **৭৫%**, user-এর trophy/difficulty কিছুই বিবেচনা করে না — Grandmaster আর Novice একই bot খেলে।
- `maybeGenerateEmote()` কে `_scheduleBotAnswer` থেকে **without roundNumber** call করা হয় (`roundNumber: 0` default) → ফলে `roundNumber <= 1` → **bot কখনো emote পাঠায় না** (dead feature)।

### ১২. Room গুলো Firestore-এ জমে থাকে — কখনো clean/complete হয় না

- ম্যাচ স্বাভাবিকভাবে শেষ হলে client room-এ `status='completed'` লেখে **না** (শুধু forfeit-এ লেখে)। `_finishDuel()` শুধু local state বদলায়।
- কেউ অ্যাপ kill করলে (forfeit dialog ছাড়া) room `in_progress` অবস্থায় চিরকাল থাকে, প্রতিপক্ষ অপেক্ষা করতেই থাকে (disconnect detection নেই — presence doc থাকলেও room-এর সাথে যুক্ত নয়)।
- Queue entry: bot fallback-এ গেলে delete হয়, কিন্তু matched হওয়া entry গুলো থেকে যায়; ১৫ সেকেন্ডের staleness চেক client-এর ঘড়ির উপর নির্ভর (clock skew হলে stale entry আবার match হতে পারে)।

**✅ সমাধান:** match শেষে server (Cloud Function) room complete + winner/trophy লিখবে; client disconnect-এ `onDisconnect` বা presence timeout দিয়ে forfeit判定।

---

## 🟡 MINOR / CODE QUALITY

### ১৩. Timer callback-এ disposed StateNotifier-এ state লেখার ঝুঁকি
`_completeRoundWithDelay()`-এর ১.৮s Timer, `_showOpponentEmote()`-এর ৩s Timer, `_emoteDismissTimer` — কোনোটাই cancel করা হয় না নতুন emote এলে (`_showOpponentEmote` প্রতিবার নতুন Timer বানায়, আগেরটা cancel হয় না — rapid emote-এ state thrash)। সব Timer `dispose()`-এ cancel করুন বা `mounted` চেক যোগ করুন।

### ১৪. `catch (_) {}` — সব error গিলে ফেলা হচ্ছে
- `findMatch()` catch-এ শুধু bot fallback (ভালো), কিন্তু কোনো logging নেই → Firestore ভুল config হলে বোঝার উপায় নেই।
- `forfeitMatch`, `updateTrophiesNow`, `_updatePresence`, challenge accept-এর room create — সব জায়গায় silent fail, user feedback নেই।
- `startQuickMatch()` catch-এ শুধু `status: idle` — radar dialog হঠা� বন্ধ হয়ে যায়, কোনো message নেই।

### ১৫. `BattleArenaStatus.roundSummary` enum value কখনো ব্যবহার হয় না (dead code); ১.৮s delay-এর সময় status `inDuel`-ই থাকে — উত্তরপত্র (correct answer/explanation) দেখানোর কোনো round summary screen নেই, যদিও model-এ `explanation` field আছে এবং UI-তে কখনো দেখানো হয় না।

### ১৬. Draw হলে `winStreak: 0` — draw সাধারণত streak রাখে, resets করে না (ডিজাইন সিদ্ধান্ত, যাচাই করুন)।

### ১৭. `BattlePlayer.currentRound` / `isReady` / `timeTakenSeconds` model-এ আছে কিন্তু game logic-এ ব্যবহার হয় না; room-level `activeEmote` একক field হওয়ায় দুই player একসাথে emote পাঠালে একটা হারিয়ে যায় (last-write-wins)।

### ১৮. `loadCuratedQuestions()` প্রতি ম্যাচে আলাদা আলাদা player আলাদাভাবে load করে — online ম্যাচে দুই player-এর ৫টা প্রশ্ন আলাদা হতে পারে!
Room তৈরির সময় questions `questions.toMap()` দিয়ে Firestore-এ লেখা হয় (joiner সেগুলোই পড়ে — ভালো), কিন্তু **room creator** local cache থেকে খেলা শুরু করে আর joiner Firestore থেকে পড়ে — creator-এর local list আর Firestore list একই object হলেও, কোনো কারণে `loadCuratedQuestions` দুইবার ভিন্ন shuffle দিলে ভিন্ন প্রশ্ন হতো। Room create করার পর creator-কেও Firestore থেকে পড়া room ব্যবহার করা নিরাপদ।

### ১৯. Presence heartbeat সবসময় `isInBattle: false` পাঠায় — ম্যাচ চলাকালীন player অনলাইন লিস্টে থেকে যায়, তাকে challenge করা যায় (সে ম্যাচে ব্যস্ত থাকলেও)। ম্যাচ শুরু হলে `isInBattle: true` শেষ হলে false করুন।

### ২০. UI: name truncation hardcoded (`substring(0, 8)` + '…'), emoji/zero-width chars-এ ভাঙতে পারে; `NetworkImage` error handling নেই (photo URL fail হলে blank avatar)।

---

## 📋 ফিক্স করার অগ্রাধিকার ক্রম

| # | কাজ | প্রভাব | পরিশ্রম |
|---|------|--------|---------|
| ১ | Round advance শর্ত ঠিক করা + Firestore round/answer sync (#1, #2) | 🔴 PvP একদম ঠিক হয়ে যাবে | M |
| ২ | Server-authoritative scoring Cloud Function (#3) | 🔴 চিটিং বন্ধ | L |
| ৩ | Matchmaking transaction + room cleanup + disconnect forfeit (#4, #12) | 🔴 | M |
| ৪ | Outgoing challenge listener + expiry (#5) | 🔴 Direct duel চালু | M |
| ৫ | timeLimit dynamic করা (#6) | 🟠 | S |
| ৬ | Trophy sync-এ userId পাঠানো / updateTrophiesNow call (#7, #8) | 🟠 | S |
| ৭ | Opponent answer/score UI + timeout sync (#9, #10) | 🟠 | M |
| ৮ | Bot difficulty + emote roundNumber fix (#11) | 🟠 | S |
| ৯ | Timer guards, error logging, dead code cleanup (#13–20) | 🟡 | S |

> 💡 **মূল স্থাপত্য সুপারিশ:** এখন পুরো game state client-driven — দুই client নিজে নিজে score/trophy/winner হিসাব করে local Hive-এ লেখে। এর মানে online leaderboard বা trophy কখনোই বিশ্বাসযোগ্য হবে না। একটা ছোট Cloud Functions সেট (room create → listen answers → round advance + score → match end → trophy distribute via transaction, presence TTL → auto-forfeit) এই পুরো feature-টাকে production-ready করে দেবে।
