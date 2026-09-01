# SpeakEasy — Battle Arena Cloud Functions

এই ফোল্ডারে Battle Arena-র **server-side** কোড আছে। ৩টি function:

| Function | টাইপ | কাজ |
|----------|------|-----|
| `onBattleRoomWrite` | Firestore trigger (realtime) | উত্তর গ্রহণ, **score যাচাই ও clamp (anti-cheat)**, ম্যাচ শেষে **server trophy বিতরণ** (+25/-10/+5), winner নির্ধারণ — একবারই (`trophiesAwarded`) |
| `cleanupBattleData` | প্রতি ৫ মিনিট | পুরনো queue (৩০s), উত্তর না-দেওয়া challenge (৯০s), পরিত্যক্ত room (৩০ মিনিট) পরিষ্কার |
| `autoForfeitDisconnectedPlayers` | প্রতি ৫ মিনিট | ৪ মিনিট heartbeat নেই অথচ ম্যাচে আছে → disconnect ধরে প্রতিপক্ষকে জয় |

---

## ⚙️ একবারের setup

### ১. Blaze plan চালু করুন (free quota-তে খরচ ৳০)
- https://console.firebase.google.com/project/flutter-spoken-english-a-c660b/usage/details
- **Modify plan → Blaze (Pay as you go)**
- একটা international card যোগ করুন (টাকা কাটবে না, শুধু verify)
- **Budget alert** বসান: $1 limit → 50% / 90% / 100% এ email

### ২. Firebase CLI লগইন (একবার)
```bash
npm install -g firebase-tools
firebase login
```

### ৩. Functions deploy
```bash
# প্রথমবার — functions folder-এ dependency install
cd functions
npm install
cd ..

# deploy
firebase deploy --only functions
```

> প্রথম deploy-এ CLI **Cloud Functions / Pub/Sub / Cloud Build API enable** করতে বলবে — হ্যাঁ (yes) বলুন, কয়েক মিনিট লাগবে।

### ৪. Firestore rules-ও deploy করা আছে কিনা নিশ্চিত হন
```bash
firebase deploy --only firestore:rules
```

---

## ✅ কীভাবে কাজ করে (data flow)

```
Player উত্তর দিল
  → client Firestore-এ লেখে: roundAnswers, roundTimes, currentScore
  → onBattleRoomWrite fire হয়
       • client score > legit হলে → server clamp করে (চিট ঠেকায়)
       • ৫ round শেষ / forfeit হলে → status=completed, winner নির্ধারণ
       • trophy server থেকে battle_presence-এ +25/-10/+5 (একবারই)

কেউ অ্যাপ kill করল:
  → ৪ মিনিট heartbeat বন্ধ
  → autoForfeit…() ম্যাচটা completed + প্রতিপক্ষ winner করে

পুরনো queue/challenge/room:
  → cleanupBattleData প্রতি ৫ মিনিটে মুছে দেয়
```

### Server score formula (client-র সাথে মেলে)
```
correct → 100 + ((timeLimit − timeTaken) × 50 / timeLimit)   = 100–150
wrong   → 0
```
Client প্রতি উত্তরের সাথে এখন `roundTimes.{round}` পাঠায়, তাই server সঠিক speed
bonus হিসাব করতে পারে। Old client (roundTimes নেই) হলে শুধু upper cap
(৫×১৫০=৭৫০) প্রয়োগ করা হয় — legit player দণ্ডিত হয় না।

---

## 💰 খরচ (free Blaze quota)
- Function call: **২০,০০,০০০/মাস পর্যন্ত ফ্রি** — এই ফিচার প্রতি ম্যাচে ~৬–১০টা call।
- হাজার হাজার daily user হলেও quota-র ভেতরেই থাকবে।
- Pub/Sub scheduled function = দিনে ২৮৮ রান (৩টি schedule মিলিয়ে) — নগণ্য।

---

## 📝 খেয়াল রাখবেন
- Trophy এখন **server-presence-এ authoritative**; client Hive শুধু instant UI-র জন্য
  (server presence trophy sync করে দেয়)। এজন্য client আর presence-এ trophy লেখে না
  (double-count এড়াতে)।
- Bot ম্যাচ (local room) Firestore-এ যায় না → function trigger হয় না, trophy শুধু local Hive-এ।
  চাইলে পরে bot trophy-ও server-নির্ভর করা যাবে।
- Logs দেখতে: `firebase functions:log`
