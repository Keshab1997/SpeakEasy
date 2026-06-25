# 🔨 Sentence Builder Game Mode

## Overview
**Sentence Builder** একটি interactive word arrangement game যেখানে খেলোয়াড়দের scrambled words থেকে সঠিক English sentence তৈরি করতে হয়।

## Features

### ✨ Core Gameplay
- **Word Arrangement**: Tap করে words select করুন এবং সঠিক ক্রমে সাজান
- **150 Unique Questions**: বিভিন্ন tenses এবং sentence structures
- **10 Questions per Game**: প্রতিটি game session এ random 10টি প্রশ্ন
- **15 Second Timer**: প্রতি প্রশ্নের জন্য 15 seconds
- **Tap to Select/Deselect**: Intuitive word selection system

### 🎯 Scoring System
- **Base Score**: 20 points per correct answer
- **Time Bonus**: Up to 10 points (2 points per remaining second)
- **Streak Bonus**: Up to 25 points (5 points per streak, max 5x)
- **Maximum per Question**: 55 points (20 + 10 + 25)

### 📊 Tense Coverage
- Present Simple
- Present Continuous
- Present Perfect
- Present Perfect Continuous
- Past Simple
- Past Continuous
- Past Perfect
- Future Simple
- Future (be going to)
- Modal Verbs

### 🎓 Difficulty Levels
- **Easy** (Green): Simple sentences, 4-5 words
- **Medium** (Orange): Complex sentences, 6-8 words
- **Hard** (Red): Advanced structures, 8+ words

## JSON Structure

```json
{
  "id": "sb_001",
  "scrambled": ["is", "This", "book", "a"],
  "correct": "This is a book",
  "tense": "present_simple",
  "difficulty": "easy",
  "hint": "Subject + be verb + article + noun",
  "explanation": "Simple Present: This/That + is/are দিয়ে কিছু চিহ্নিত করা হয়"
}
```

### Field Descriptions
- **id**: Unique question identifier (sb_001 to sb_150)
- **scrambled**: Array of shuffled words
- **correct**: The correct sentence formation
- **tense**: Tense category for the sentence
- **difficulty**: easy/medium/hard
- **hint**: Structural pattern hint in English
- **explanation**: Detailed explanation in Bangla

## Gameplay Flow

1. **Question Display**: Scrambled words shown at bottom
2. **Selection**: User taps words to build sentence in answer area
3. **Deselection**: Tap selected words to remove them
4. **Submission**: Submit button appears when words are selected
5. **Feedback**: Instant feedback with explanation
6. **Next**: Auto-advance after 2.5 seconds

## UI Components

### Header Bar
- Question number (1/10)
- Progress bar
- Timer circle (green → red as time decreases)
- Stats: Score, Streak, Correct count

### Question Card
- Tense badge (e.g., PRESENT SIMPLE)
- Difficulty badge (EASY/MEDIUM/HARD)
- Instruction text

### Answer Area
- Drop zone for selected words
- Visual feedback (green for correct, red for wrong)
- Empty state message when no words selected

### Word Chips
- **Available Words**: Blue gradient chips
- **Selected Words**: Light blue chips with border
- Tap interaction with visual feedback

### Hint System
- Optional hint button
- Shows sentence structure pattern
- Amber colored hint box

## Visual Design

### Color Scheme
- **Primary**: Blue gradient (#1565C0 → #42A5F5)
- **Success**: Green (#4CAF50)
- **Error**: Red (#F44336)
- **Warning**: Amber (#FFC107)
- **Streak**: Orange (#FF9800)

### Animations
- Shake animation on wrong answer
- Progress bar animation
- Timer countdown effect
- Word tap feedback

## Rewards

### XP Calculation
```
Earned XP = Score × 2
```

### Coin Calculation
```
Earned Coins = Score + min(Streak × 5, 50)
```

### Wrong Answer Tracking
- Saves to `WrongQuestionRepository`
- Available for review in Answer Review screen
- Includes user's answer vs correct answer

## Educational Value

### Learning Objectives
1. **Sentence Structure**: Understanding English word order
2. **Grammar Rules**: Subject-Verb-Object patterns
3. **Tense Usage**: Identifying and using correct tenses
4. **Quick Thinking**: Time pressure improves recall
5. **Pattern Recognition**: Learning common sentence patterns

### Examples by Difficulty

**Easy:**
- "This is a book" (4 words)
- "He goes to school every day" (6 words)

**Medium:**
- "I will go to the market tomorrow" (7 words)
- "They didn't come to the party" (6 words)

**Hard:**
- "We have been waiting for two hours" (7 words)
- "He is the tallest boy in the class" (8 words)

## File Locations

- **JSON Data**: `/assets/json/game/sentence_builder_data.json`
- **Screen**: `/lib/features/game/screens/modes/sentence_builder_mode.dart`
- **Entry Point**: Game Home Screen → "Sentence Builder" card

## Integration

### Result Screen
Results displayed with:
- Total score
- Correct/Wrong count
- Earned XP and Coins
- Retry option returns to game mode

### Statistics
Game results tracked in:
- Total games played
- Overall accuracy
- Total XP earned
- Total coins earned

## Tips for Players

1. **Read Carefully**: প্রথমে সব words দেখে নিন
2. **Start with Subject**: সাধারণত subject দিয়ে শুরু করুন
3. **Use Hints**: Stuck হলে hint ব্যবহার করুন
4. **Watch Timer**: সময় শেষ হওয়ার আগে submit করুন
5. **Learn from Mistakes**: Wrong answers review করুন

## Future Enhancements

- [ ] Punctuation support (periods, question marks)
- [ ] Compound sentences (multiple clauses)
- [ ] Difficulty filtering
- [ ] Category-wise practice (only Present tense, etc.)
- [ ] Multiplayer mode
- [ ] Daily sentence challenges
- [ ] Voice pronunciation after correct answer

---

**Created**: June 25, 2026  
**Version**: 1.0.0  
**Game Mode**: Sentence Builder 🔨