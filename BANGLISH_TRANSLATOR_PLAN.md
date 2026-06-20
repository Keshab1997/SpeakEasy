# Banglish → English Translator Page — Plan

## ধারণা (Concept)

User বাংলা কথা English alphabet দিয়ে type করবে (Banglish)।
App সেটা English এ translate করবে — শুধু translation না, **কেন এই grammar rule** সেটাও বাংলায় বুঝিয়ে দেবে।

---

## Page এর Structure

### 1. Input Area (উপরে)
- একটা বড় text field
- Placeholder: `"Banglish likho... jemon: ami school jabo"`
- User type করলে নিচে result আসবে (real-time বা button press এ)

---

### 2. Result Card (নিচে, translation এর পরে)

Result কার্ডে **৩টি অংশ** থাকবে:

#### অংশ ১ — English Translation
```
✅ Correct English:
"I will go to school."
```

#### অংশ ২ — Grammar Rule Breakdown (word by word)

প্রতিটা word আলাদা chip/badge হিসেবে দেখাবে।
প্রতিটা word এর উপর tap করলে নিচে সেই word এর grammar role দেখাবে।

উদাহরণ:
```
[ I ]  [ will ]  [ go ]  [ to ]  [ school ]
  ↑
tap করলে দেখাবে:
━━━━━━━━━━━━━━━━━━━━━━
শব্দ: "I"
Grammar Role: Subject (কর্তা)
বাংলায় মানে: "আমি"
কেন এখানে বসেছে: বাংলায় বলি "আমি যাবো" — English এ sentence শুরু হয় Subject দিয়ে। "I" হলো 1st person singular subject।
━━━━━━━━━━━━━━━━━━━━━━

শব্দ: "will"
Grammar Role: Auxiliary Verb (সাহায্যকারী ক্রিয়া)
বাংলায় মানে: ভবিষ্যতের কাজ বোঝায়
কেন এখানে বসেছে: "jabo" মানে "যাবো" — এটা Future Tense। English এ Future Tense বোঝাতে Subject এর পরে "will" বসে, তারপর main verb এর base form।
━━━━━━━━━━━━━━━━━━━━━━

শব্দ: "go"
Grammar Role: Main Verb (মূল ক্রিয়া)
বাংলায় মানে: "যাওয়া"
কেন এখানে বসেছে: "will" এর পরে সবসময় verb এর base form বসে। "goes" বা "went" না, শুধু "go"।
━━━━━━━━━━━━━━━━━━━━━━

শব্দ: "to"
Grammar Role: Preposition (পদান্বয়ী অব্যয়)
বাংলায় মানে: "তে / এ / কে"
কেন এখানে বসেছে: কোনো জায়গায় যাওয়া বোঝালে "go to [place]" pattern ব্যবহার হয়।
━━━━━━━━━━━━━━━━━━━━━━

শব্দ: "school"
Grammar Role: Object / Place (গন্তব্য)
বাংলায় মানে: "স্কুল"
কেন এখানে বসেছে: এটা destination (গন্তব্য), তাই "to" এর পরে বসেছে।
```

#### অংশ ৩ — Tense / Rule Summary (একটা box)
```
📌 Rule টা কী?
Sentence: Future Tense (ভবিষ্যৎ কাল)
Pattern: Subject + will + verb (base form) + object

বাংলায় যখন "বো/বে/বি" থাকে (যাবো, খাবো, করবো)
→ English এ "will + verb" ব্যবহার করো।

আরো উদাহরণ:
• সে আসবে → He will come
• তারা খাবে → They will eat
• আমরা পড়বো → We will study
```

---

## আরেকটা উদাহরণ — "ami khacchi"

#### English Translation:
```
✅ "I am eating."
```

#### Word Breakdown:
```
[ I ]  [ am ]  [ eating ]

শব্দ: "am"
Grammar Role: Helping Verb — Present Continuous
বাংলায় মানে: "আছি / হচ্ছি"
কেন এখানে বসেছে: "khacchi" মানে "খাচ্ছি" — এটা Present Continuous Tense। "I" এর সাথে "am" বসে।

শব্দ: "eating"
Grammar Role: Main Verb + -ing form
কেন এখানে বসেছে: Present Continuous এ verb এর সাথে -ing যোগ হয়। "eat" → "eating"।
```

#### Rule Summary:
```
📌 Present Continuous Tense
Pattern: Subject + am/is/are + verb(-ing)

বাংলায় যখন "ছি/ছে/ছেন" থাকে (খাচ্ছি, যাচ্ছে, করছেন)
→ English এ "am/is/are + verb+ing" ব্যবহার করো।
```

---

## Page এ আরো যা থাকবে

### TTS Button (🔊)
- Translation এর পাশে একটা speaker icon
- Press করলে English sentence টা বলে দেবে (flutter_tts দিয়ে)

### Copy Button (📋)
- Translation copy করার জন্য

### Try Another Button
- Input clear করে নতুন sentence লেখার সুযোগ

### Common Examples (নিচে)
কিছু ready-made example দেবে যেগুলো tap করলে সেটা input এ চলে যাবে:
- "ami tomake valobashi"
- "kal ami bari jabo"
- "tumi ki khaccho"
- "se school e jay"
- "amra khub khushi"

---

## Navigation

- Home Screen এর Quick Practice grid এ **"Translate"** নামে একটা নতুন item যোগ হবে
- অথবা AI Teacher Banner এর নিচে একটা shortcut card

---

## AI এর কাছে কী চাইতে হবে (Prompt Design)

AI কে এই format এ response দিতে বলতে হবে:

```
Input: "ami school jabo"

তোমার কাজ:
1. সঠিক English translation দাও
2. প্রতিটা English word আলাদাভাবে explain করো:
   - শব্দ কী
   - Grammar role কী (Subject/Verb/Object/Preposition ইত্যাদি)
   - বাংলায় মানে কী
   - কেন এই position এ বসেছে — বাংলায় সহজ ভাষায় বুঝিয়ে দাও
3. কোন Tense বা Grammar Pattern ব্যবহার হয়েছে সেটা বাংলায় বুঝিয়ে দাও
4. সেই pattern এর আরো ২-৩টা উদাহরণ দাও
```

---

## সংক্ষেপে Flow

```
User types: "ami school jabo"
        ↓
AI processes
        ↓
Page দেখায়:
  ✅ English: "I will go to school."
  🔊 [Speaker Button]
  
  Word Cards:
  [I] [will] [go] [to] [school]
  (tap করলে বিস্তারিত)
  
  📌 Rule: Future Tense
  Pattern: Subject + will + verb
  বাংলায়: "বো/বে/বি" থাকলে "will" ব্যবহার করো
  
  আরো examples: ...
```

---

## File কোথায় বানাতে হবে

```
lib/
└── features/
    └── translator/
        └── screens/
            └── banglish_translator_screen.dart
```

এই screen টা `GrammarListScreen` বা `ConversationScreen` এর মতো করে বানাতে হবে।
Navigation: Home → Quick Practice → "Translate" tap → এই screen।
