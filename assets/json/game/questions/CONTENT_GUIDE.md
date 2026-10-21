# 📚 Question Content Authoring Guide

এই গাইডটি পড়লে তুমি নিজে নিজে প্রতিটি tense-এর জন্য প্রশ্ন লিখতে পারবে।

---

## 🗂 ফাইল লোকেশন

সব প্রশ্ন এই ফোল্ডারে রয়েছে:

```
assets/json/game/questions/
├── 01_present_indefinite.json
├── 02_present_continuous.json
├── 03_present_perfect.json
├── 04_present_perfect_continuous.json
├── 05_past_indefinite.json
├── 06_past_continuous.json
├── 07_past_perfect.json
├── 08_past_perfect_continuous.json
├── 09_future_indefinite.json
├── 10_future_continuous.json
├── 11_future_perfect.json
└── 12_future_perfect_continuous.json
```

প্রতিটি tense-এর জন্য একটি করে ফাইল। কোনো প্রশ্ন কোন tense-এর ভেতরে আছে, সেটাই সেই tense-এর প্রশ্ন।

---

## 📋 লেখার ক্রম (Order)

এই অর্ডারে লিখবে:

1. Present Indefinite → `01_present_indefinite.json`
2. Present Continuous → `02_present_continuous.json`
3. Present Perfect → `03_present_perfect.json`
4. Present Perfect Continuous → `04_present_perfect_continuous.json`
5. Past Indefinite → `05_past_indefinite.json`
6. Past Continuous → `06_past_continuous.json`
7. Past Perfect → `07_past_perfect.json`
8. Past Perfect Continuous → `08_past_perfect_continuous.json`
9. Future Indefinite → `09_future_indefinite.json`
10. Future Continuous → `10_future_continuous.json`
11. Future Perfect → `11_future_perfect.json`
12. Future Perfect Continuous → `12_future_perfect_continuous.json`

**একটা tense শেষ করে তারপর পরেরটায় যাওয়া ভালো।**

---

## 🔧 ফাইল স্ট্রাকচার

প্রতিটি ফাইল এই ফরম্যাটে হবে:

```json
{
  "tenseType": "Present Indefinite",
  "version": "1.0.0",
  "lastUpdated": "2026-06-21",
  "questions": [
    { ... question 1 ... },
    { ... question 2 ... },
    { ... question 3 ... }
  ]
}
```

- `tenseType` — অবশ্যই ওই ফাইলের tense-এর নাম হবে (নিচের তালিকা দেখো)।
- `version` — `1.0.0` রাখো।
- `lastUpdated` — আজকের তারিখ (YYYY-MM-DD) লিখো।
- `questions` — এখানে সব প্রশ্ন থাকবে।

### ⚠️ `tenseType` এর সঠিক নাম (হুবহু এই নাম ব্যবহার করতে হবে)

| ফাইল | tenseType |
|------|-----------|
| 01 | `Present Indefinite` |
| 02 | `Present Continuous` |
| 03 | `Present Perfect` |
| 04 | `Present Perfect Continuous` |
| 05 | `Past Indefinite` |
| 06 | `Past Continuous` |
| 07 | `Past Perfect` |
| 08 | `Past Perfect Continuous` |
| 09 | `Future Indefinite` |
| 10 | `Future Continuous` |
| 11 | `Future Perfect` |
| 12 | `Future Perfect Continuous` |

> ভুল নাম লিখলে প্রশ্ন গেমে দেখাবে না, কারণ গেম `tenseType` দিয়ে ফিল্টার করে।

---

## 🧬 একটি প্রশ্নের স্কিমা (Schema)

প্রতিটি প্রশ্ন এই ফিল্ডগুলো রাখবে:

| ফিল্ড | টাইপ | বাধ্যতামূলক? | কী লিখবে |
|------|------|-------------|----------|
| `id` | String | ✅ হ্যাঁ | ইউনিক আইডি, যেমন `pi_001` (Present Indefinite, প্রশ্ন ১) |
| `tenseType` | String | ✅ হ্যাঁ | উপরের টেবিলের নাম |
| `question` | String | ✅ হ্যাঁ | প্রশ্ন / বাক্য (মোড ভেদে ভিন্ন — নিচে দেখো) |
| `options` | Array of String | ✅ হ্যাঁ | ৪টি অপশন |
| `correctAnswer` | String | ✅ হ্যাঁ | ঠিক উত্তর — অবশ্যই `options` এর মধ্যে থাকতে হবে |
| `explanation` | String | ✅ হ্যাঁ | কেন এটাই সঠিক উত্তর — বাংলায় বা ইংরেজিতে |
| `difficulty` | String | ✅ হ্যাঁ | `easy` / `medium` / `hard` |
| `mode` | String | ✅ হ্যাঁ | `fill_blank` / `choose_tense` / `sentence_builder` / `error_detection` / `translation_challenge` / `speed_quiz` |
| `xpReward` | Number | ❌ ঐচ্ছিক | ডিফল্ট `10` |
| `coinReward` | Number | ❌ ঐচ্ছিক | ডিফল্ট `5` |

---

## 🎮 ৬টি মোড কীভাবে লিখবে

### 1️⃣ `mode: "fill_blank"` — Fill in the Blank

বাক্যের মাঝে ফাঁকা থাকবে (`____`)। ইউজার সঠিক শব্দটি বসাবে।

```json
{
  "id": "pi_001",
  "tenseType": "Present Indefinite",
  "question": "She ____ tea every morning.",
  "options": ["drink", "drinks", "drinking", "drank"],
  "correctAnswer": "drinks",
  "explanation": "Present Indefinite-এ third person singular (she/he/it)-এর সাথে verb-এর শেষে 's' বসে। তাই 'drink' → 'drinks'।",
  "difficulty": "easy",
  "mode": "fill_blank"
}
```

**নিয়ম:**
- `question`-এ ফাঁকা বোঝাতে `____` (৪টি underscore) ব্যবহার করো।
- `correctAnswer` অবশ্যই `options` এর একটির সাথে হুবহু মিলবে।

---

### 2️⃣ `mode: "choose_tense"` — Choose Correct Tense

পূর্ণ বাক্য দেওয়া থাকবে, ইউজার বলবে এটা কোন tense।

```json
{
  "id": "pi_002",
  "tenseType": "Present Indefinite",
  "question": "I go to school every day.",
  "options": ["Present Indefinite", "Present Continuous", "Present Perfect", "Present Perfect Continuous"],
  "correctAnswer": "Present Indefinite",
  "explanation": "'every day' ঘুরে ঘুরে হওয়া অভ্যাস বোঝায়, আর এখানে base verb 'go' ব্যবহৃত হয়েছে — তাই এটি Present Indefinite।",
  "difficulty": "easy",
  "mode": "choose_tense"
}
```

**নিয়ম:**
- প্রশ্নে ফাঁকা থাকবে না।
- `options` হবে ৪টি tense-এর নাম।
- বাক্যটি যে tense-এর ফাইলে আছে, সেটাই সাধারণত সঠিক উত্তর হবে — তবে ভুল করে ভিন্ন tense-এর বাক্য না দেওয়ার জন্য সাবধান।

---

### 3️⃣ `mode: "sentence_builder"` — Sentence Builder

শব্দগুলো এলোমেলো দেওয়া থাকবে, ইউজার সাজাবে। কিন্তু যেহেতু আমাদের সিস্টেম ৪টি অপশন MCQ ফরম্যাটে কাজ করে, তাই `question`-এ এলোমেলো শব্দ দেবে আর `options`-এ ৪টি সাজানো বাক্যের সম্ভাবনা দেবে।

```json
{
  "id": "pi_003",
  "tenseType": "Present Indefinite",
  "question": "Arrange: (every / plays / cricket / day / he)",
  "options": [
    "He plays cricket every day.",
    "He play cricket every day.",
    "He plays cricket day every.",
    "Every day he playing cricket."
  ],
  "correctAnswer": "He plays cricket every day.",
  "explanation": "সঠিক ক্রম: Subject (He) + Verb (plays, কারণ third person singular) + Object (cricket) + Time (every day)।",
  "difficulty": "medium",
  "mode": "sentence_builder"
}
```

**নিয়ম:**
- `question`-এ শুরুতে `Arrange:` লিখে এলোমেলো শব্দগুলো `/` দিয়ে আলাদা করো।
- বাক্যটি লেখার সময় সবসময় `.` বা `?` দিয়ে শেষ করবে।
- ১টি সঠিক + ৩টি প্রায়-সঠিক কিন্তু ভুল বাক্য দেবে।

---

### 4️⃣ `mode: "error_detection"` — Error Detection

বাক্যে একটি ভুল থাকবে। ইউজার সঠিক সংস্করণটি বেছে নেবে।

```json
{
  "id": "pi_004",
  "tenseType": "Present Indefinite",
  "question": "Find the error: 'He go to office every day.'",
  "options": [
    "He goes to office every day.",
    "He going to office every day.",
    "He gone to office every day.",
    "He went to office every day."
  ],
  "correctAnswer": "He goes to office every day.",
  "explanation": "'He' third person singular, তাই 'go' এর সাথে 'es' যুক্ত হয়ে 'goes' হবে।",
  "difficulty": "medium",
  "mode": "error_detection"
}
```

**নিয়ম:**
- `question`-এ শুরুতে `Find the error:` লিখে ভুল বাক্যটি single quote-এ দেবে।
- `correctAnswer` হবে সঠিক বাক্যটি।
- বাক্য না শুনে শুধু ভুল শব্দটি চিহ্নিত করানোর ধারণা এড়িয়ে চলো — আমাদের UI MCQ ফরম্যাটে কাজ করে।

---

### 5️⃣ `mode: "translation_challenge"` — Translation Challenge

বাংলা বাক্য ইংরেজিতে অনুবাদ করতে হবে (অথবা উল্টো)।

```json
{
  "id": "pi_005",
  "tenseType": "Present Indefinite",
  "question": "Translate: 'সে প্রতিদিন স্কুলে যায়।'",
  "options": [
    "He goes to school every day.",
    "He is going to school every day.",
    "He went to school every day.",
    "He has gone to school every day."
  ],
  "correctAnswer": "He goes to school every day.",
  "explanation": "'প্রতিদিন যায়' মানে ঘুরে ঘুরে হওয়া কাজ — Present Indefinite। তাই 'goes' (third person singular) সঠিক।",
  "difficulty": "medium",
  "mode": "translation_challenge"
}
```

**নিয়ম:**
- `question`-এ শুরুতে `Translate:` লিখে বাংলা বাক্য single quote-এ দেবে।
- ৪টি অপশনের মধ্যে শুধু ১টি সঠিক অনুবাদ।

---

### 6️⶟ `mode: "speed_quiz"` — Speed Quiz

এটি সাধারণ MCQ — কিন্তু টাইমারের সাথে দ্রুত উত্তর দিতে হয়। সহজ ও ছোট প্রশ্ন রাখবে।

```json
{
  "id": "pi_006",
  "tenseType": "Present Indefinite",
  "question": "Choose the correct form: 'They ____ football now.' — Wait, is this Present Indefinite? Pick the Present Indefinite version.",
  "options": [
    "They play football every day.",
    "They are playing football now.",
    "They played football yesterday.",
    "They have played football."
  ],
  "correctAnswer": "They play football every day.",
  "explanation": "'every day' অভ্যাস বোঝায় এবং base verb 'play' ব্যবহৃত — এটি Present Indefinite।",
  "difficulty": "easy",
  "mode": "speed_quiz"
}
```

**নিয়ম:**
- প্রশ্ন ছোট ও সরল রাখবে — ইউজারের দ্রুত পড়তে হবে।
- `difficulty` সাধারণত `easy` রাখবে (কারণ টাইম কম)।

---

## 📊 কঠিনতা (Difficulty) নির্দেশিকা

| Difficulty | কেমন হবে | কোথায় ব্যবহৃত |
|-----------|---------|--------------|
| `easy` | প্রাথমিক নিয়ম, পরিচিত শব্দ, সরল বাক্য | সাধারণ Practice, Speed Quiz |
| `medium` | কিছুটা জটিল নিয়ম, বড় বাক্য | Daily Challenge (intermediate), সাধারণ খেলা |
| `hard` | কঠিন নিয়ম, ব্যতিক্রম, কনফিউজিং অপশন | উচ্চতর লেভেলের প্র্যাকটিস |

> ⚠️ প্রতিটি tense-এ কিছু `hard` প্রশ্ন রাখুন, যাতে advanced learners-দের জন্যও পর্যাপ্ত practice থাকে।
>
> **বি.দ্র:** Daily Challenge-র জন্য `medium` বা `intermediate` — দুটোই কাজ করবে না। গেমটি হার্ডকোড করা `difficulty: 'intermediate'` খোঁজে। তাই `medium`-এর বদলে **`intermediate`** ব্যবহার করো Daily Challenge-র প্রশ্নে।
>
> **চূড়ান্ত নিয়ম:** difficulty-তে শুধু এই ৩টি মান ব্যবহার করো: `easy`, `intermediate`, `hard`।

---

## 🎯 প্রতি tense-এ কতগুলো প্রশ্ন দরকার?

**টার্গেট:** প্রতি tense-এ অন্তত **৩০টি প্রশ্ন**।

বিভাজন এরকম রাখতে পারো:

| Mode | সহজ (easy) | মধ্যম (intermediate) | কঠিন (hard) | মোট |
|------|-----------|------------------|------------|-----|
| fill_blank | 3 | 2 | 2 | 7 |
| choose_tense | 3 | 2 | 1 | 6 |
| sentence_builder | 2 | 2 | 1 | 5 |
| error_detection | 2 | 2 | 2 | 6 |
| translation_challenge | 2 | 2 | 1 | 5 |
| speed_quiz | 2 | 0 | 0 | 2 |
| **মোট** | **14** | **10** | **7** | **~৩১** |

> বেশি প্রশ্ন লিখলে আরও ভালো — খেলোয়াড় একই প্রশ্ন বারবার দেখবে না।

---

## ✅ চেকলিস্ট — প্রশ্ন লেখার আগে ও পরে

### লেখার আগে:
- [ ] সঠিক tense-এর ফাইল খুলেছি (`01_present_indefinite.json` ইত্যাদি)
- [ ] `tenseType` ফাইলের সাথে মিলে যাচ্ছে
- [ ] প্রশ্নটি সত্যিই ওই tense-এর নিয়ম অনুসরণ করছে

### প্রতিটি প্রশ্নের পরে:
- [ ] `id` ইউনিক (একই আইডি দুবার নয়)
- [ ] `options`-এ ঠিক ৪টি অপশন আছে
- [ ] `correctAnswer` ঠিক `options`-এর একটির সাথে হুবহু মিলে যাচ্ছে (case, punctuation সহ)
- [ ] `explanation` আছে এবং বোঝানো হয়েছে কেন এটাই সঠিক
- [ ] `difficulty` হলো `easy` / `intermediate` / `hard`
- [ ] `mode` হলো নিচের ৬টির একটি: `fill_blank`, `choose_tense`, `sentence_builder`, `error_detection`, `translation_challenge`, `speed_quiz`

### ফাইল সেভ করার পরে:
- [ ] JSON বৈধ (ভুল কমা, কোটেশন নেই) — [jsonlint.com](https://jsonlint.com)-এ যাচাই করো
- [ ] সব প্রশ্নের `tenseType` ফাইলের সাথে মিলছে

---

## 🚨 সাধারণ ভুলসমূহ (Avoid These)

| ❌ ভুল | ✅ সঠিক |
|--------|--------|
| `"correctAnswer": "drinks"` কিন্তু options-এ `"Drinks"` (বড় হাতের) | Case হুবহু মিলিয়ে লিখবে |
| `id` দুবার ব্যবহার | প্রতিটি id ইউনিক রাখবে (`pi_001`, `pi_002` ...) |
| শেষ প্রশ্নের পরে `,` বসিয়ে দেওয়া | JSON-এ শেষ আইটেমের পরে কমা নিষেধ |
| `difficulty: "Beginner"` | `difficulty: "easy"` (ছোট হাতের, নির্দিষ্ট শব্দ) |
| `mode: "Fill in the Blank"` | `mode: "fill_blank"` ( Underscore, ছোট হাতের) |
| `options`-এ সঠিক উত্তর নেই | `correctAnswer` অবশ্যই options-এর ভেতরে থাকবে |
| বাংলা বাক্যে ইংরেজি কোটেশন ব্যবহার | JSON এস্কেপ করা বা single quote ব্যবহার করো |

---

## 🔤 ID কনভেনশন

প্রতিটি tense-এর জন্য একটি করে সংক্ষিপ্ত নাম ব্যবহার করো:

| Tense | Prefix | উদাহরণ ID |
|-------|--------|----------|
| Present Indefinite | `pi` | `pi_001`, `pi_002` |
| Present Continuous | `pc` | `pc_001` |
| Present Perfect | `pp` | `pp_001` |
| Present Perfect Continuous | `ppc` | `ppc_001` |
| Past Indefinite | `pai` | `pai_001` |
| Past Continuous | `pac` | `pac_001` |
| Past Perfect | `pap` | `pap_001` |
| Past Perfect Continuous | `papc` | `papc_001` |
| Future Indefinite | `fi` | `fi_001` |
| Future Continuous | `fc` | `fc_001` |
| Future Perfect | `fp` | `fp_001` |
| Future Perfect Continuous | `fpc` | `fpc_001` |

---

## 🧪 একটি সম্পূর্ণ ফাইলের উদাহরণ

`01_present_indefinite.json` দেখতে এমন হবে:

```json
{
  "tenseType": "Present Indefinite",
  "version": "1.0.0",
  "lastUpdated": "2026-06-21",
  "questions": [
    {
      "id": "pi_001",
      "tenseType": "Present Indefinite",
      "question": "She ____ tea every morning.",
      "options": ["drink", "drinks", "drinking", "drank"],
      "correctAnswer": "drinks",
      "explanation": "Third person singular (she) → 'drink' এর সাথে 's' যুক্ত হয়ে 'drinks'।",
      "difficulty": "easy",
      "mode": "fill_blank"
    },
    {
      "id": "pi_002",
      "tenseType": "Present Indefinite",
      "question": "Identify the tense: 'I go to school every day.'",
      "options": ["Present Indefinite", "Present Continuous", "Present Perfect", "Past Indefinite"],
      "correctAnswer": "Present Indefinite",
      "explanation": "'every day' অভ্যাস বোঝায় এবং base verb 'go' ব্যবহৃত — Present Indefinite।",
      "difficulty": "easy",
      "mode": "choose_tense"
    },
    {
      "id": "pi_003",
      "tenseType": "Present Indefinite",
      "question": "Arrange: (every / plays / cricket / day / he)",
      "options": [
        "He plays cricket every day.",
        "He play cricket every day.",
        "He plays cricket day every.",
        "Every day he playing cricket."
      ],
      "correctAnswer": "He plays cricket every day.",
      "explanation": "Subject + Verb + Object + Time। 'He' → 'plays'।",
      "difficulty": "intermediate",
      "mode": "sentence_builder"
    }
  ]
}
```

---

## ❓ সাহায্য

- **JSON কাজ করছে কি না যাচাই:** [jsonlint.com](https://jsonlint.com)
- **কোন tense-এর নিয়ম ভুলে গেছো?** `assets/json/grammar/chapter_21_introduction_to_tense.json` পড়ো।
- **আরও প্রশ্নের আইডিয়া:** অনলাইনে "present indefinite exercises" সার্চ করলে প্রচুর উদাহরণ পাবে।

**মনে রাখো:** শুধু একটা tense লিখে গেমে টেস্ট করে দেখো কাজ করছে কি না, তারপর বাকিগুলো লেখো। এতে ভুল ধরা সহজ হবে।
