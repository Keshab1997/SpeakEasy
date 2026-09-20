# ⏳ Battle Arena — Challenge Lifecycle Rules

**Version:** 1.0.46+46 · Client-side + server-side (dোয়ে স্তরে enforce)

## নিয়মগুলো এক নজরে

| ঘটনা | কী হয় | কোথায় enforce |
|---|---|---|
| 📨 Live challenge পাঠানো হলো (target online) | **৯০ সেকেন্ড** সময় পাবে সাড়া দিতে | Client (`isExpired`) + server sweep |
| 📨 Async challenge পাঠানো হলো (target offline) | **৪৮ ঘণ্টা** পর্যন্ত অপেক্ষা করবে | Client + server sweep |
| ⏰ Request-এর মেয়াদ শেষ | Doc + room **মুছে ফেলা হয়** — sheet/banner/Pending ⏳ কিছুতেই আর দেখা যাবে না, Duel button তৎক্ষণাৎ unlock | Gate sweep + providers |
| 🚫 Receiver **Decline** করলে | Room **সাথে সাথেই** cancel → ১০ সেকেন্ড পর challenge doc-ও **সম্পূর্ণ erase** (sender-এর "declined" জানার ১০ সে. সুযোগ রেখে) | `_rejectAndErase` |
| ✖️ Sender **Cancel** করলে | Challenge doc + room সঙ্গে সঙ্গে মুছে যায় | `_cancelPendingChallenge` |
| ✅ Accept হলে | বাকি সব pending request auto-decline + সেগুলোর room/doc-ও full teardown | `_declineOtherPendingChallenges` |
| 🧹 Server sweep (Cloud Function, প্রতি ৫ মিনিটে) | Expired live (৯০s) / async (৪৮h) / rejected (১০ মিনিট) / accepted-অবহেলিত (২h) / stale queue (৩০s) / stale waiting rooms — সব পরিষ্কার | `cleanupBattleData` |

## কেন দুই স্তরে?

Cloud Function কোড repo-তে থাকলেও **deploy করতে হয়**, আর sweep চলে প্রতি ৫ মিনিটে।
তাই এখন client নিজেই TTL enforce করে — deploy থাকুক বা না থাকুক, ৯০ সেকেন্ড পর
পুরনো request আর কোনো UI-তে দেখা যাবে না এবং Firestore থেকেও মুছে যাবে।

## মূল কোড

- `BattleChallenge.isExpired` + `liveTtl`/`asyncTtl` — battle_models.dart
- Gate: `_sweepExpiredChallenge` / `_rejectAndErase` — global_battle_challenge_gate.dart
- Providers: expired pending UI থেকে বাদ — battle_presence_provider.dart
- Lobby banner: expired-তে Respond দেখায় না — battle_lobby_screen.dart
