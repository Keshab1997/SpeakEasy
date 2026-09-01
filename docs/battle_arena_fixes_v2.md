# 🛠️ Battle Arena — Fixes (branch: fix/battle-arena-bugs)

রিভিউ রিপোর্ট (`docs/battle_arena_code_review.md`) থেকে নিচের bug গুলো এই ব্রাঞ্চে fix করা হয়েছে —
সবগুলো **client-side + Firestore rules**, কোনো Cloud Function লাগেনি।

## যা ঠিক করা হলো

### 🐛 Direct Challenge — challenge accept করলে sender প্রশ্ন দেখত না (#৫)
- `BattlePresenceService.listenToOutgoingChallenges()` যোগ — নিজের পাঠানো challenge-এর status listen করা।
- নতুন `outgoingChallengesProvider`।
- Lobby-তে outgoing listener: **Accept** হলে sender Firestore থেকে room এনে নিজে duel-এ ঢোকে (`getRoom` + `startFromRoom`), room তৈরি propagate হতে দেরি হলে একবার retry; **Reject** হলে snackbar।
- শেষ হয়ে যাওয়া challenge doc auto-delete (housekeeping)।
- দুইবার fire ঠেকাতে `_handledOutgoingChallengeIds` guard।

### 🐛 Online 1v1-তে round এগিয়ে যাওয়ার ভুল শর্ত (#১)
- আগে: `if (isOpponentAnswered || opponent.isBot == false)` → মানুষ প্রতিপক্ষ থাকলেই আপনার উত্তরের সাথে সাথে round এগিয়ে যেত (প্রতিপক্ষ উত্তর দিক বা না দিক)।
- এখন: **দুইজনেই উত্তর দিলে** তবেই advance; না হলে round timer (১৫s) শেষ হলে advance।
- উত্তর এখন per-round map-এ রাখা হয়: `player.roundAnswers.{roundIndex}` — ফলে আগের round-এর পুরনো উত্তর নতুন প্রশ্নে আর ভুল করে দেখায় না।
- `submitAnswer` Firestore-এ round-keyed answer লেখে; room subscription শুধু **current round**-এর answer পড়ে।

### 🐛 Round skip / double transition (#২)
- `_roundTransitioning` guard + `_roundTransitionTimer` field — answer আর timer-এর race এখন round দুইবার এড়ায় না।

### 🐛 Opponent score সময়মতো sync না হওয়া (#১০)
- প্রতিটা room snapshot-এ opponent-এর live score sync হয় (শুধু উত্তর আসার সময় নয়) — time-out/late answer-এও সঠিক score।
- Match শেষে (`_finishDuel`) online হলে Firestore থেকে **সর্বশেষ opponent score** টেনে এনে winner ঠিক করা হয়, তারপর room `completed` চিহ্নিত করা হয় (`completeRoom`)।

### 🐛 হার্ডকোডেড `15` → question.timeLimit (#৬)
- Timer, score calculation, UI timer bar সব এখন `question.timeLimit` ব্যবহার করে।
- `calculateRoundScore(..., roundTimeLimit:)` — speed bonus এখন time limit অনুপাতে।
- Question loader asset JSON-এর `timeLimit` পড়ে।

### 🐛 Trophy Firestore-এ sync হতো না (#৭)
- `saveMatchResult(userId:)` এখন সব জায়গা থেকে (`_finishDuel`, forfeit win, forfeit loss) current user id পায় → presence doc-এ trophy সাথে সাথে update হয়।

### 🐛 Bot কখনো emote পাঠাত না (#১১)
- `maybeGenerateEmote(roundNumber: currentRoundIndex + 1)` পাঠানো হচ্ছে — আগে default 0 পাঠাত বলে সবসময় null ছিল।

### 👀 প্রতিপক্ষের উত্তর দেখা যায় না (#৯)
- Option tile-এ প্রতিপক্ষের বেছে নেওয়া অপশনে ছোট 🔴 person marker (answer reveal হওয়ার পর)।

### 🛡️ Firestore rules — প্রতিটা live update REJECT হতো
- আগের update rule প্রতিবার `request.resource.data.player1.id` দাবি করত, কিন্তু client partial update করে (যেমন শুধু `player1.roundAnswers.0`) → partial map-এ `id` নেই → **score/emote/forfeit সব write ব্যর্থ হতো**।
- নতুন `battlePlayersUnchanged()` + `battleQuestionsUnchanged()` — partial update allow করে, player id ও questions immutable রাখে।

### 🧹 অন্যান্য
- সব Timer callback-এ `mounted` guard; নতুন emote এলে আগের emote timer cancel (leak fix)।
- Dispose/reset-এ নতুন সব timer cancel।
- Forfeit win একাধিকবার fire না হওয়ার guard।

## ⚠️ যা এখনো বাকি (পরের ধাপে — Cloud Functions লাগবে)
- **Server-authoritative score/trophy** (#৩): এখনও client score পাঠায়; চিটিং ঠেকাতে Cloud Function দরকার (Blaze plan, free quota-তে খরচ ৳০)।
- Matchmaking transaction (#৪), room auto-cleanup ও disconnect auto-forfeit (#১২)।
- Pending challenge auto-expiry (TTL)।
- Bot difficulty trophy-ভিত্তিক করা; round-এর explanation দেখানো (summary screen)।

> টেস্ট: `flutter analyze` চালিয়ে নিন; দুই ডিভাইস/অ্যাকাউন্টে direct challenge accept করে sender-এর স্ক্রিনে প্রশ্ন আসে কিনা যাচাই করুন।
