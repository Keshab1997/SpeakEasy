# 🛠️ Battle Arena — Resend-after-Decline + Question Sync Fix

**Version:** 1.0.43+43

## User-reported bugs

1. **"Decline korar por abar request pathale, accept korleo take dekhay je exit hye geche"**
   — একজন player challenge decline করার পর, sender আবার challenge পাঠালে receiver
   "Joining…" ক্লিক করলেও host-এর স্ক্রিনে "<Player> left the room." দেখাত।
2. **"Accept kore match chalu holé dujon ke alada question dekhay"**
   — match শুরু হলে দুই player-এর সামনে দুই রকম question আসত (একই room, একই seed)।

## Root causes

### Bug 1 — মিথ্যা "left the room" (poison write)

Guest waiting-room স্ক্রিনে room-এর প্রথম read (`getRoom`) transient ভাবে fail করলে
(নতুন room doc এখনো device-এর Firestore cache-এ নেই / network glitch — resend-এর
সময় খুবই সাধারণ) স্ক্রিনটা pop হত, আর `PopScope`-এর guest branch **কোনো শর্ত
ছাড়াই** `markPlayer2Left()` লিখে দিত। ফলে সুস্থ room-এই `player2LeftAt` সেট হয়ে
যেত এবং host দেখত "**left the room**"।

পাশাপাশি host-এর waiting room `streamChallenge`-এর **transient null emission**-কে
"declined" ভেবে room মুছে দিত — resend-এর delete+re-set replace window-তে এটি
ঘটে; আর gate-এর rejected-handler-এর **late backlog emission** নতুন challenge doc
(negative deterministic id-এর কারণে একই id) মুছে দিতে পারত।

### Bug 2 — আলাদা question (non-deterministic seeded selection)

`generateSeededQuestions()` প্রতিটা ডিভাইসের **Hive-এ থাকা "শেষ ২০টা খেলা"র
question-id লিস্ট** দিয়ে pool ফিল্টার করত। দুই ডিভাইসের recent লিস্ট আলাদা হওয়ায়
একই seed-এ shuffle করলেও ভিন্ন ফল আসত — sender room তৈরির সময়, receiver accept-এর
সময় regenerate করে, ফলাফল ভিন্ন।

## Fixes

| ফাইল | কী ঠিক হলো |
|---|---|
| `battle_game_service.dart` | Seeded selection এখন **pure (seed, pool)** — per-device recentIds সম্পূর্ণ বাদ। Repeat protection শুধু bot-duel path-এ (`excludeIds` param)। `questionSetVersion` 1 → 2 |
| `battle_waiting_room_screen.dart` | `_everSawRoom` flag — room দেখার আগে `player2LeftAt` লেখা অসম্ভব; fail-জoints `_leaveWithoutMarkingLeft()` দিয়ে pop; `getRoom` retry; host-এর decline detection এখন fresh re-read দিয়ে verify করে; version-mismatch warning banner |
| `global_battle_challenge_gate.dart` | `_onAccept` fresh challenge re-read করে stale sheet-object ঠেকায় (dead room-এ join বন্ধ); rejected-cleanup নিশ্চিত করে doc টা এখনো সেই rejected instance কি না — নতুন challenge doc আর মুছে না |
| `battle_presence_service.dart` | `getChallenge()` helper (throws on read failure — "doc নেই" vs "পড়া গেল না" আলাদা করা যায়) |

## প্রত্যাশিত আচরণ এখন

- Decline → পরে resend → accept: receiver সরাসরি **নতুন room-এ** ঢোকে, host-এ
  "X is ready! 🔥" দেখায়, START দিলেই দুজনে একই question নিয়ে খেলে।
- ভিন্ন app version-এর দুজন waiting room-এ ঢোকার **আগেই** ⚠️ warning দেখবে।
- Transient network fail-এ আর কেউ মিথ্যা "left"/"declined" signal পাবে না।
