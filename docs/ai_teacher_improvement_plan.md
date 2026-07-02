# 🤖 AI Teacher — Improvement Plan

> File: `lib/features/ai_teacher/screens/ai_chat_screen.dart` | Lines: 859
> Current Status: Basic Chat UI ✅ | Missing Features: Many 🟡

---

## Current Features (What's Already There)

| Feature | Status | Details |
|---------|--------|---------|
| Chat with AI | ✅ | OpenAI-compatible API via `AIService` |
| Speech-to-Text Input | ✅ | English & Bangla voice input |
| Markdown Rendering | ✅ | Using `flutter_markdown` |
| Chat History (Hive) | ✅ | Save/load/delete sessions |
| Suggested Questions | ✅ | Extracted from AI response |
| Dark Mode Support | ✅ | Full theme adaptation |
| API Key Setup Flow | ✅ | Settings → Setup Guide |
| Language Toggle | ✅ | EN/BN speech locale |
| Auto-save on close | ✅ | `_autoSaveSession()` in dispose |

---

## 🔴 Phase 1: Quick Wins (1-2 hours each)

### 1.1 Add Typing Animation
Instead of showing full response at once, stream tokens with typewriter effect.

```dart
// Instead of setState({ _messages.add({'text': fullResponse}) })
// Use a streaming approach
String _streamingText = '';
void _simulateTyping(String fullText) {
  for (int i = 0; i < fullText.length; i++) {
    Future.delayed(Duration(milliseconds: 15 * i), () {
      setState(() => _streamingText = fullText.substring(0, i + 1));
    });
  }
}
```

**Benefit**: More engaging, feels like real conversation.

### 1.2 Add Timestamp Grouping
Group messages sent within 2 minutes into bubbles with single timestamp.

**Benefit**: Cleaner chat UI, less noise.

### 1.3 Add Copy Button on AI Messages
Currently only long-press copies. Add a visible copy icon on hover/tap.

**Benefit**: Better UX for saving vocabulary/grammar tips.

### 1.4 Add Quick Action Buttons
Below the input bar, show 3-4 quick action chips:
- "📝 Check my grammar"
- "📖 Teach me a word"  
- "💬 Conversation practice"
- "✍️ Correct this sentence"

These send structured prompts to the AI.

**Benefit**: Onboarding — users often don't know what to ask.

---

## 🟡 Phase 2: Core Improvements (2-4 hours each)

### 2.1 Grammar Correction Mode
A dedicated mode where user pastes a sentence, AI returns structured correction:

```
Your sentence: ✅/❌
─────────────────
🔴 Error: [wrong part]
🟢 Correction: [right part]
📖 Rule: [grammar rule in Bangla]
📝 Similar example: [...]
```

**Implementation**: Add a toggle/button "Grammar Check Mode" that changes the system prompt to a strict grammar correction format.

### 2.2 Pre-built Lesson Templates
Add a "Lessons" tab within AI Teacher with scaffolded exercises:

| Lesson | Duration | Description |
|--------|----------|-------------|
| Introduce Yourself | 5 min | AI guides user through self-intro |
| Ordering Food | 5 min | Restaurant conversation practice |
| Job Interview | 10 min | Mock interview Q&A |
| Daily Routine | 5 min | Describe your day |
| Past Events | 5 min | Tell a story about yesterday |

**Implementation**: A horizontal scrollable carousel above the chat. Each lesson has structured prompts.

### 2.3 Pronunciation Practice
Use `flutter_tts` + `speech_to_text` **together**:
1. AI shows a sentence
2. TTS plays correct pronunciation 
3. User speaks
4. STT captures user speech
5. Compare with expected text → show accuracy %

### 2.4 Vocabulary Learning from Chat
Auto-detect new words in AI responses and let user save them:

```
AI: "The word 'ubiquitous' means..."
                    ╔═══════════════════╗
                    ║ ★ Save to Vocab   ║
                    ╚═══════════════════╝
```

When tapped, word + meaning + example get saved to Hive/Firestore vocabulary collection.

---

## 🟠 Phase 3: Advanced Features (4-8 hours each)

### 3.1 Voice Conversation Mode
Full conversation without typing:
1. Tap microphone → speak
2. STT converts to text → send to AI
3. AI responds → TTS reads aloud
4. Repeat

Toggle between "Chat Mode" and "Voice Mode".

### 3.2 Writing Evaluation
User submits a paragraph → AI evaluates:
- Grammar score (0-100)
- Vocabulary level (A1-C2)
- Fluency suggestions
- Re-written improved version

Rendered as a beautiful score card with color-coded sections.

### 3.3 Daily Challenge in AI Teacher
Every day, AI generates a new challenge:
- "Write 5 sentences in Past Tense"
- "Describe this picture in English"
- "Find 3 errors in this paragraph"

Track completions with streak.

### 3.4 AI-Generated Exercises
User selects a topic → AI generates:

| Exercise Type | Example |
|--------------|---------|
| Fill in blanks | "She ___ (go) to school yesterday." |
| MCQ | "Choose the correct tense..." |
| Error detection | "Find the error: He go to school." |
| Sentence reordering | "Rearrange: school / go / I / to" |

---

## 🔵 Phase 4: Polish & Scale (Future)

### 4.1 Image Support
User can upload a screenshot/image → AI describes it or corrects text in image.

### 4.2 AI Teacher Profile Customization
- Choose AI personality: Strict teacher / Friendly friend / Professional coach
- Choose response style: Short & concise / Detailed & explanatory
- AI avatar customization

### 4.3 Feedback Mechanism
Thumbs up/down on each AI response → improves prompt engineering over time.

### 4.4 Weekly Progress Report
AI generates weekly summary:
- Topics covered
- New vocabulary learned  
- Accuracy trend
- Weak areas to focus

---

## 📊 Effort Estimate Summary

| Phase | Features | Est. Time |
|-------|----------|-----------|
| 🔴 Phase 1 | 4 quick wins | 4-6 hours |
| 🟡 Phase 2 | 4 core improvements | 10-16 hours |
| 🟠 Phase 3 | 4 advanced features | 16-24 hours |
| 🔵 Phase 4 | 4 polish items | 12-16 hours |
| **Total** | **16 features** | **42-62 hours** |

---

## 🎯 Recommended First Steps (Top 3 Priority)

1. **Quick Action Buttons** (Phase 1.4) — 30 min — Biggest UX improvement for least effort
2. **Grammar Correction Mode** (Phase 2.1) — 2 hours — Most requested feature
3. **Voice Conversation Mode** (Phase 3.1) — 4 hours — Differentiator from other apps

---

## 🖼️ UI Mock Concepts

### Chat with Grammar Correction
```
┌─────────────────────────────────────────┐
│  🤖 Keshab            🔴 ... ─── ⚙️ 🕐 │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────┐           │
│  │ She go to school        │ 😎  ← user│
│  │                 12:30 PM │           │
│  └──────────────────────────┘           │
│                                         │
│  ┌──────────────────────────────────────┤
│  │ 📝 **Grammar Correction**           │
│  │                                      │
│  │ 🔴 **Error**: "She go"              │
│  │    → Subject-verb agreement ❌      │
│  │                                      │
│  │ 🟢 **Correct**: "She **goes**"      │
│  │    → "She goes to school."          │
│  │                                      │
│  │ 📖 **Rule**:                        │
│  │    He/She/It → verb + s/es          │
│  │    যেমন: He plays, She eats         │
│  │                                      │
│  │ 💡 **Try**: Correct this →         │
│  │    "He play football every day" 💬  │
│  └──────────────────────────────────────┤
│                                         │
│  [📝 Grammar] [📖 Vocab] [💬 Chat]     │
│  ┌─────────────────────────╥──┐        │
│  │ Type here...           ║ 🎤│🎙️ ▸  │
│  └─────────────────────────╨──┘        │
└─────────────────────────────────────────┘
```

### Quick Action Bar
```
┌─────────────────────────────────────────────────┐
│ 📝 Check Grammar  │ 📖 New Word  │ 💬 Practice  │
└─────────────────────────────────────────────────┘
```

---

## 📁 Proposed File Structure

```
lib/features/ai_teacher/
├── screens/
│   └── ai_chat_screen.dart          (current, 859 lines)
├── widgets/
│   ├── grammar_correction_card.dart  (NEW)
│   ├── quick_action_bar.dart         (NEW)
│   ├── lesson_carousel.dart          (NEW)
│   ├── voice_mode_bar.dart           (NEW)
│   └── vocab_save_button.dart        (NEW)
├── providers/
│   └── ai_teacher_provider.dart      (NEW — state management)
└── models/
    └── ai_lesson_model.dart          (NEW — lesson templates)
```

**Split recommendation**: Current `ai_chat_screen.dart` (859 lines) should be broken into:
- `ai_chat_screen.dart` — layout + composition (~200 lines)
- `_buildChatMessage()` → `chat_message_widget.dart`  
- `_showHistoryDrawer()` → `chat_history_drawer.dart`
- Input bar → `chat_input_bar.dart`

---

## 🚀 Quick Implementation Guide

### First Feature: Quick Action Bar (30 min)

```dart
// In ai_chat_screen.dart, above the input field:
Container(
  height: 40,
  child: ListView(
    scrollDirection: Axis.horizontal,
    children: [
      _buildActionChip('📝 Check Grammar', _onGrammarCheck),
      _buildActionChip('📖 New Word', _onNewWord),
      _buildActionChip('💬 Practice', _onPractice),
    ],
  ),
);

void _onGrammarCheck() {
  _messageController.text = 'Please check this sentence for grammar errors: ';
  _messageController.selection = TextSelection.fromPosition(
    TextPosition(offset: _messageController.text.length),
  );
}
```

### Second Feature: Grammar Correction Mode (2 hours)
1. Add state bool `_grammarMode = false`
2. Add toggle button in app bar
3. When ON, send with stricter system prompt
4. Parse AI response into structured card sections
5. Render with colored error/correction indicators