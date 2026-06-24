# 🎮 Game JSON Files

এই ডিরেক্টরিতে বিভিন্ন গেম মোডের জন্য JSON data files রয়েছে।

## 📁 Current Game Modes

| File | Game Mode | Description |
|------|-----------|-------------|
| `word_match_data.json` | Word Match | বাংলা ↔ English word pairs matching |
| `verb_quiz_data.json` | Quick Quiz | বাংলা → English verb quiz (5-sec timer) |
| `fill_blanks_data.json` | Fill in the Blanks | Grammar-focused blank filling (verb/preposition/article) |

---

## 📝 How to Add New Game Content

### 1️⃣ **Word Match Game**

নতুন word pairs যোগ করতে `word_match_data.json` edit করুন:

```json
{
  "pairs": [
    { "bn": "আম", "en": "mango" },
    { "bn": "নতুন শব্দ", "en": "new word" }
  ]
}
```

### 2️⃣ **Quick Quiz (Verb Quiz)**

নতুন verb pairs যোগ করতে `verb_quiz_data.json` edit করুন:

```json
{
  "pairs": [
    { "bn": "খাওয়া", "en": "eat" },
    { "bn": "নতুন verb", "en": "new verb" }
  ]
}
```

### 3️⃣ **Fill in the Blanks**

নতুন grammar questions যোগ করতে `fill_blanks_data.json` edit করুন:

```json
{
  "questions": [
    {
      "id": "fb_031",
      "sentence": "He ___ to school every day.",
      "blank": "goes",
      "options": ["go", "goes", "going", "went"],
      "type": "verb",
      "tense": "present_simple",
      "explanation": "3rd person singular এর জন্য verb-এ 's' যুক্ত হয়",
      "difficulty": "easy"
    }
  ]
}
```

**Required Fields:**
- `id`: Unique identifier (fb_031, fb_032, ...)
- `sentence`: Question with `___` as blank
- `blank`: Correct answer
- `options`: Array of 4 options (including correct answer)
- `type`: `verb` | `preposition` | `article` | `conjunction`
- `tense`: Grammar tense/rule name
- `explanation`: বাংলায় explanation
- `difficulty`: `easy` | `medium` | `hard`

---

## ✅ Validation & Auto-Build

### GitHub Action Workflow

যখন আপনি JSON file যোগ/edit করবেন:

1. **Automatic Validation** 🔍
   - Push করার সাথে সাথে GitHub Action চলবে
   - JSON syntax validate হবে
   - ❌ Invalid JSON থাকলে build fail করবে

2. **Auto Merge to Main** 🚀
   - ✅ Valid JSON হলে automatically merge হবে
   - কোনো manual build করার প্রয়োজন নেই

### Workflow Triggers:
```yaml
on:
  push:
    paths:
      - 'assets/json/game/**/*.json'
```

---

## 🧪 Local Testing

JSON file valid কিনা local এ check করুন:

```bash
# Single file validation
python3 -m json.tool assets/json/game/fill_blanks_data.json

# All game JSON files
find assets/json/game -name "*.json" -exec python3 -m json.tool {} \;
```

---

## 📋 JSON Structure Guidelines

### ✅ DO:
- Use consistent formatting (2-space indentation)
- Always include all required fields
- Use meaningful IDs (sequential: fb_001, fb_002, ...)
- Write clear Bengali explanations
- Test locally before pushing

### ❌ DON'T:
- Don't use duplicate IDs
- Don't skip required fields
- Don't use special characters that break JSON
- Don't leave trailing commas

---

## 🆕 Adding a New Game Mode

নতুন game mode যোগ করতে হলে:

1. **JSON Data File তৈরি করুন:**
   ```
   assets/json/game/your_game_data.json
   ```

2. **Game Screen তৈরি করুন:**
   ```
   lib/features/game/screens/modes/your_game_mode.dart
   ```

3. **Register করুন:**
   - `game_home_screen.dart` এ card যোগ করুন
   - `result_screen.dart` এ retry logic যোগ করুন

4. **Push করুন:**
   - GitHub Action automatically validate করবে
   - ✅ Valid থাকলে merge হবে

---

## 📞 Need Help?

- JSON syntax error? Run: `python3 -m json.tool your_file.json`
- Question about structure? Check existing files as examples
- Report issues using `/reportbug` command

---

**Happy Contributing! 🎉**