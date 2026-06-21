# Tense Mastery Module — সম্পূর্ণ Workflow

## Overview

এই module টা বিদ্যমান Grammar module এর exact same pattern এ তৈরি হবে।
Grammar module যেভাবে কাজ করে — JSON → Model → Provider → Screens — Tense module ও একই পথে যাবে।

---

## Project এ এখন যা আছে (Reference)

```
lib/
├── models/grammar_chapter_model.dart       ← এই pattern follow করবো
├── providers/grammar_provider.dart         ← এই pattern follow করবো
└── features/grammar/screens/
    ├── grammar_list_screen.dart            ← এই pattern follow করবো
    ├── grammar_detail_screen.dart
    └── grammar_test_screen.dart

assets/json/grammar/
    chapter_01_alphabet.json               ← এই format follow করবো
    chapter_02_word.json
    ...
```

---

## Step 1 — JSON Data তৈরি করো (সবচেয়ে আগে)

### ফোল্ডার তৈরি করো

```
assets/json/tense/
    chapter_01_what_is_tense.json
    chapter_02_present_indefinite.json
    chapter_03_present_continuous.json
    chapter_04_present_perfect.json
    chapter_05_present_perfect_continuous.json
    chapter_06_past_indefinite.json
    chapter_07_past_continuous.json
    chapter_08_past_perfect.json
    chapter_09_past_perfect_continuous.json
    chapter_10_future_indefinite.json
    chapter_11_future_continuous.json
    chapter_12_future_perfect.json
    chapter_13_future_perfect_continuous.json
    chapter_14_present_indefinite_vs_continuous.json
    chapter_15_past_indefinite_vs_present_perfect.json
    chapter_16_future_indefinite_vs_continuous.json
    chapter_17_special_usage.json
    chapter_18_spoken_english_patterns.json
    chapter_19_practice_section.json
    chapter_20_final_test.json
```

### প্রতিটা JSON এর Structure

নিচে Chapter 2 (Present Indefinite) এর উদাহরণ দেওয়া হলো — বাকি সব এই format এ হবে:

```json
{
  "chapter": 2,
  "level": "Beginner",
  "title": "Present Indefinite Tense",
  "banglaTitle": "সাধারণ বর্তমান কাল",
  "icon": "present_indefinite",
  "description": "Used for habitual actions, general truths, and permanent situations.",
  "banglaDescription": "যে কাজ নিয়মিত হয়, সত্য কথা বা স্থায়ী অবস্থা বোঝাতে Present Indefinite Tense ব্যবহার হয়।",

  "formula": {
    "positive": "Subject + Verb(s/es) + Object",
    "negative": "Subject + do/does + not + Verb + Object",
    "question": "Do/Does + Subject + Verb + Object?",
    "wh_question": "WH-word + do/does + Subject + Verb + Object?"
  },

  "signalWords": ["always", "usually", "often", "sometimes", "never", "every day", "daily", "regularly"],
  "banglaSignalWords": ["সবসময়", "সাধারণত", "প্রায়ই", "কখনো কখনো", "কখনো না", "প্রতিদিন"],

  "topics": [
    {
      "name": "Definition",
      "banglaName": "সংজ্ঞা",
      "definition": "Present Indefinite Tense describes actions that happen regularly or are always true.",
      "banglaDefinition": "যে কাজ নিয়মিত হয় বা সর্বদা সত্য সেটা বোঝাতে এই Tense ব্যবহার হয়।",
      "examples": [
        { "en": "I play cricket.", "bn": "আমি ক্রিকেট খেলি।" },
        { "en": "She reads books every day.", "bn": "সে প্রতিদিন বই পড়ে।" },
        { "en": "The sun rises in the east.", "bn": "সূর্য পূর্ব দিকে ওঠে।" }
      ]
    },
    {
      "name": "Positive Sentences",
      "banglaName": "হ্যাঁ-বাচক বাক্য",
      "formula": "Subject + Verb(s/es) + Object",
      "banglaDefinition": "3rd person singular (He/She/It) এর সাথে verb এর শেষে s বা es যোগ হয়।",
      "rules": [
        "I/You/We/They এর সাথে verb এর base form বসে",
        "He/She/It এর সাথে verb এর শেষে s বা es যোগ হয়",
        "go → goes, watch → watches, study → studies"
      ],
      "examples": [
        { "en": "I go to school.", "bn": "আমি স্কুলে যাই।" },
        { "en": "He goes to school.", "bn": "সে স্কুলে যায়।" },
        { "en": "They play football.", "bn": "তারা ফুটবল খেলে।" }
      ]
    },
    {
      "name": "Negative Sentences",
      "banglaName": "না-বাচক বাক্য",
      "formula": "Subject + do/does + not + Verb + Object",
      "banglaDefinition": "না-বাচক বাক্যে I/You/We/They এর সাথে 'do not' এবং He/She/It এর সাথে 'does not' বসে।",
      "rules": [
        "I/You/We/They → do not (don't) + verb base form",
        "He/She/It → does not (doesn't) + verb base form",
        "does not এর পরে verb এ s/es যোগ হয় না"
      ],
      "examples": [
        { "en": "I do not play cricket.", "bn": "আমি ক্রিকেট খেলি না।" },
        { "en": "She does not read books.", "bn": "সে বই পড়ে না।" },
        { "en": "They do not go to school.", "bn": "তারা স্কুলে যায় না।" }
      ]
    },
    {
      "name": "Interrogative Sentences",
      "banglaName": "প্রশ্নবাচক বাক্য",
      "formula": "Do/Does + Subject + Verb + Object?",
      "banglaDefinition": "প্রশ্ন করতে Do বা Does বাক্যের শুরুতে বসে।",
      "examples": [
        { "en": "Do you play cricket?", "bn": "তুমি কি ক্রিকেট খেলো?" },
        { "en": "Does she read books?", "bn": "সে কি বই পড়ে?" },
        { "en": "Do they go to school?", "bn": "তারা কি স্কুলে যায়?" }
      ]
    },
    {
      "name": "WH Questions",
      "banglaName": "WH প্রশ্ন",
      "formula": "WH-word + do/does + Subject + Verb + Object?",
      "examples": [
        { "en": "What do you eat?", "bn": "তুমি কী খাও?" },
        { "en": "Where does he live?", "bn": "সে কোথায় থাকে?" },
        { "en": "Why do they study?", "bn": "তারা কেন পড়ে?" }
      ]
    }
  ],

  "commonMistakes": [
    {
      "wrong": "She go to school.",
      "correct": "She goes to school.",
      "explanation": "He/She/It এর সাথে verb এ s/es যোগ করতে হয়।"
    },
    {
      "wrong": "He does not goes.",
      "correct": "He does not go.",
      "explanation": "does not এর পরে verb এর base form বসে, s/es যোগ হয় না।"
    },
    {
      "wrong": "Does she reads?",
      "correct": "Does she read?",
      "explanation": "Does দিয়ে প্রশ্ন করলে verb এ s/es লাগে না।"
    }
  ],

  "exercises": {
    "fillInTheBlanks": [
      {
        "sentence": "She ___ (go) to school every day.",
        "answer": "goes",
        "explanation": "She = 3rd person singular, তাই goes।"
      },
      {
        "sentence": "They ___ (not/play) football.",
        "answer": "do not play",
        "explanation": "They এর সাথে do not বসে।"
      }
    ],
    "mcq": [
      {
        "question": "He ___ cricket every evening.",
        "options": ["play", "plays", "played", "is playing"],
        "answer": "plays",
        "explanation": "He = 3rd person singular, Present Indefinite তাই plays।"
      }
    ],
    "translation": [
      {
        "bangla": "আমি প্রতিদিন ইংরেজি পড়ি।",
        "answer": "I read English every day.",
        "hint": "Subject + Verb + Object + signal word"
      },
      {
        "bangla": "সে স্কুলে যায় না।",
        "answer": "She does not go to school.",
        "hint": "She + does not + verb base form"
      }
    ],
    "sentenceCorrection": [
      {
        "wrong": "He do not eat rice.",
        "correct": "He does not eat rice.",
        "explanation": "He এর সাথে does not বসে।"
      }
    ]
  },

  "spokenPatterns": [
    {
      "pattern": "I usually ___.",
      "example": "I usually wake up at 6 AM.",
      "bangla": "আমি সাধারণত সকাল ৬টায় উঠি।"
    },
    {
      "pattern": "She always ___.",
      "example": "She always drinks tea in the morning.",
      "bangla": "সে সবসময় সকালে চা পান করে।"
    }
  ]
}
```

### Chapter Level অনুযায়ী ভাগ

| Level | Chapters |
|-------|----------|
| Beginner | 1, 2, 3, 6, 10 |
| Intermediate | 4, 5, 7, 8, 11, 12, 14, 15, 16, 17 |
| Advanced | 9, 13, 18, 19, 20 |

---

## Step 2 — Dart Model Class তৈরি করো

### ফাইল তৈরি করো

```
lib/models/tense_chapter_model.dart
```

### Class গুলো কী কী লাগবে

```
TenseExample       → en (English), bn (বাংলা)
TenseMistake       → wrong, correct, explanation
TenseFormula       → positive, negative, question, wh_question
TenseExercise      → fillInTheBlanks, mcq, translation, sentenceCorrection
TenseTopic         → name, banglaName, definition, banglaDefinition, formula, rules, examples
TenseChapter       → chapter, level, title, banglaTitle, description, topics, exercises, commonMistakes, signalWords, spokenPatterns
```

Grammar module এর `GrammarChapter` model এর exact same structure, শুধু extra fields যোগ হবে:
- `banglaTitle`
- `formula` (TenseFormula object — positive/negative/question আলাদা)
- `signalWords`
- `banglaSignalWords`
- `exercises` (TenseExercise object)
- `spokenPatterns`

---

## Step 3 — Provider তৈরি করো

### ফাইল তৈরি করো

```
lib/providers/tense_provider.dart
```

### Grammar provider এর exact same pattern

```dart
// Grammar provider যেভাবে আছে:
final grammarAssetPathsProvider   → assets/json/grammar/ থেকে load করে
final allGrammarChaptersProvider  → সব chapter load করে
final chaptersByLevelProvider     → level অনুযায়ী group করে

// Tense provider একই pattern এ:
final tenseAssetPathsProvider     → assets/json/tense/ থেকে load করবে
final allTenseChaptersProvider    → সব tense chapter load করবে
final tenseByLevelProvider        → level অনুযায়ী group করবে (Beginner/Intermediate/Advanced)
```

Cache key: `tense_cache_version` (grammar এর মতো versioning থাকবে)

---

## Step 4 — pubspec.yaml এ asset path যোগ করো

```yaml
assets:
  - assets/json/grammar/      # ইতিমধ্যে আছে
  - assets/json/tense/        # এটা নতুন যোগ করতে হবে
```

---

## Step 5 — Screens তৈরি করো

### ফোল্ডার ও ফাইল

```
lib/features/tense/screens/
    tense_list_screen.dart
    tense_detail_screen.dart
    tense_exercise_screen.dart
    tense_test_screen.dart
```

### Screen 1: tense_list_screen.dart

Grammar List Screen এর exact same layout।

**যা থাকবে:**
- AppBar: "Tense Mastery" title
- Top tabs: 🌱 Beginner | 📖 Intermediate | 🚀 Advanced
- Chapter cards list — chapter number, title, topic count
- Tap করলে → TenseDetailScreen

**Grammar List Screen থেকে পার্থক্য:**
- রঙ একটু আলাদা হতে পারে (teal/green theme)
- Chapter number এর পাশে tense type icon (🕐 Present, ⏮ Past, ⏭ Future)

---

### Screen 2: tense_detail_screen.dart

এই screen এ একটা chapter এর সব content দেখাবে।

**Layout (উপর থেকে নিচে):**

```
━━━━━━━━━━━━━━━━━━━━━━━━━
AppBar: Chapter Title (বাংলা নামও দেখাবে)
━━━━━━━━━━━━━━━━━━━━━━━━━

1. Formula Card (উপরে সবুজ background)
   ✅ Positive: Subject + Verb(s/es) + Object
   ❌ Negative: Subject + do/does + not + Verb
   ❓ Question: Do/Does + Subject + Verb?

2. Signal Words (horizontal scroll chips)
   [always] [usually] [often] [every day]

3. Topics List (accordion / expandable)
   ▶ Definition (tap করলে expand)
      - English definition
      - বাংলা definition
      - Examples

   ▶ Positive Sentences
      - Rule বাংলায়
      - Examples (en + bn)

   ▶ Negative Sentences
   ▶ Questions
   ▶ WH Questions

4. Common Mistakes Section
   ❌ Wrong: She go to school.
   ✅ Correct: She goes to school.
   💡 কারণ: He/She/It এর সাথে s/es যোগ হয়।

5. Spoken Patterns Section
   Pattern examples + বাংলা

6. Bottom Buttons
   [📝 Practice Exercises]  [🧪 Take Test]
━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Screen 3: tense_exercise_screen.dart

Exercise করার screen।

**৪ ধরনের exercise থাকবে (tab এ ভাগ করা):**

**Tab 1 — Fill in the Blanks**
```
She ___ (go) to school.
[TextField input]
[Check ✓] বোতাম
→ সঠিক হলে: ✅ "goes" — সবুজ
→ ভুল হলে: ❌ সঠিক উত্তর + explanation বাংলায়
```

**Tab 2 — MCQ**
```
He ___ cricket every evening.
(A) play   (B) plays   (C) played   (D) is playing
→ tap করলে সাথে সাথে সঠিক/ভুল দেখাবে
→ explanation বাংলায়
```

**Tab 3 — Translation**
```
বাংলা: "আমি প্রতিদিন ইংরেজি পড়ি।"
[TextField]
[Check] বোতাম
→ Hint button: "Subject + Verb + Object"
```

**Tab 4 — Sentence Correction**
```
❌ He do not eat rice.
তুমি কী মনে করো সঠিক বাক্যটা কী?
[TextField]
[Check]
→ ✅ He does not eat rice.
→ কারণ বাংলায়
```

**Score tracking:** প্রতিটা exercise শেষে score দেখাবে।

---

### Screen 4: tense_test_screen.dart

Chapter 20 এর Final Test এবং প্রতিটা chapter এর শেষে mini test।

**Test types (Chapter 20 থেকে):**
- Beginner: 50 questions
- Intermediate: 100 questions
- Advanced: 150 questions

**প্রতিটা question:**
- Timer (optional)
- Progress bar
- Question number / total

**Test শেষে:**
- Score দেখাবে (X/Total)
- Correct/Wrong breakdown
- Weak area detection (কোন tense এ ভুল বেশি)
- Revision suggestion

---

## Step 6 — Route যোগ করো

### route_names.dart এ যোগ করো

```dart
static const tenseList = '/tense-list';
static const tenseDetail = '/tense-detail';
static const tenseExercise = '/tense-exercise';
static const tenseTest = '/tense-test';
```

### app_routes.dart এ যোগ করো

```dart
case RouteNames.tenseList:
  return MaterialPageRoute(builder: (_) => const TenseListScreen());
```

---

## Step 7 — Navigation Entry Point যোগ করো

### Home Screen এর Quick Practice grid এ

`home_screen.dart` এর `_buildQuickPracticeSection` এ একটা নতুন item যোগ হবে:

```dart
{'title': 'Tense', 'icon': Icons.access_time_rounded, 'gradient': AppColors.infoGradient, 'tab': -5}
```

এবং switch case এ:
```dart
} else if (tab == -5) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const TenseListScreen()));
}
```

---

## সম্পূর্ণ File তৈরির List (Checklist)

### JSON Files (20টা)
```
☐ assets/json/tense/chapter_01_what_is_tense.json
☐ assets/json/tense/chapter_02_present_indefinite.json
☐ assets/json/tense/chapter_03_present_continuous.json
☐ assets/json/tense/chapter_04_present_perfect.json
☐ assets/json/tense/chapter_05_present_perfect_continuous.json
☐ assets/json/tense/chapter_06_past_indefinite.json
☐ assets/json/tense/chapter_07_past_continuous.json
☐ assets/json/tense/chapter_08_past_perfect.json
☐ assets/json/tense/chapter_09_past_perfect_continuous.json
☐ assets/json/tense/chapter_10_future_indefinite.json
☐ assets/json/tense/chapter_11_future_continuous.json
☐ assets/json/tense/chapter_12_future_perfect.json
☐ assets/json/tense/chapter_13_future_perfect_continuous.json
☐ assets/json/tense/chapter_14_present_indefinite_vs_continuous.json
☐ assets/json/tense/chapter_15_past_indefinite_vs_present_perfect.json
☐ assets/json/tense/chapter_16_future_indefinite_vs_continuous.json
☐ assets/json/tense/chapter_17_special_usage.json
☐ assets/json/tense/chapter_18_spoken_english_patterns.json
☐ assets/json/tense/chapter_19_practice_section.json
☐ assets/json/tense/chapter_20_final_test.json
```

### Dart Files (6টা)
```
☐ lib/models/tense_chapter_model.dart
☐ lib/providers/tense_provider.dart
☐ lib/features/tense/screens/tense_list_screen.dart
☐ lib/features/tense/screens/tense_detail_screen.dart
☐ lib/features/tense/screens/tense_exercise_screen.dart
☐ lib/features/tense/screens/tense_test_screen.dart
```

### Modify করতে হবে (4টা)
```
☐ pubspec.yaml                   → assets/json/tense/ যোগ করো
☐ lib/routes/route_names.dart    → tense routes যোগ করো
☐ lib/routes/app_routes.dart     → tense screen routes যোগ করো
☐ lib/features/home/screens/home_screen.dart → Quick Practice এ "Tense" যোগ করো
```

---

## কোথা থেকে কাজ শুরু করবো

### ধাপ ১ — JSON আগে

JSON ছাড়া কিছু test করা যাবে না। তাই সবার আগে অন্তত ২-৩টা chapter এর JSON তৈরি করো:
1. `chapter_02_present_indefinite.json` (সহজ, পরিচিত)
2. `chapter_03_present_continuous.json`
3. `chapter_06_past_indefinite.json`

এই ৩টা দিয়ে পুরো workflow test করা যাবে। বাকি ১৭টা পরে করা যাবে।

### ধাপ ২ — Model + Provider

JSON তৈরি হলে model আর provider লেখো। Grammar module এর code copy করে rename করলেই ৮০% কাজ হয়ে যাবে।

### ধাপ ৩ — List Screen + Detail Screen

Grammar List Screen এর code base হিসেবে নিয়ে Tense List Screen বানাও।

### ধাপ ৪ — Exercise Screen

এটা নতুন — Grammar module এ নেই। এটা শেষে করো।

### ধাপ ৫ — Test Screen

Chapter 20 এর data তৈরি হলে test screen করো।

---

## সারসংক্ষেপ Flow Chart

```
Tense_Mastery_Module_Syllabus.md
           ↓
   JSON Files (20টা)
   assets/json/tense/
           ↓
   tense_chapter_model.dart
   (Model class)
           ↓
   tense_provider.dart
   (Data loading)
           ↓
   pubspec.yaml update
           ↓
   tense_list_screen.dart    ← Chapter list
           ↓
   tense_detail_screen.dart  ← Theory + Examples
           ↓
   tense_exercise_screen.dart ← Practice (Fill, MCQ, Translation)
           ↓
   tense_test_screen.dart    ← Final Test + Score
           ↓
   route_names.dart
   app_routes.dart
   home_screen.dart (Quick Practice grid)
```

---

## Important Notes

**Grammar module থেকে যা সরাসরি reuse করা যাবে:**
- `GrammarChapter.fromJson()` pattern → TenseChapter.fromJson()
- `grammar_provider.dart` → tense_provider.dart (শুধু path আর class নাম বদলাবে)
- `GrammarListScreen` layout → TenseListScreen (same widget structure)

**নতুন যা যোগ হবে:**
- Formula card (positive/negative/question আলাদা)
- Signal words chips
- Exercise tabs (Fill / MCQ / Translation / Correction)
- Score tracking
- Weak area detection (final test এ)
