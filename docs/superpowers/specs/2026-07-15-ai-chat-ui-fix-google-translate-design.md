# AI Chat Screen UI Fix + Google Translate Integration

**Date:** 2026-07-15
**Status:** Approved Design

## Overview

Fix the AI Chat Screen UI to remove API-key dependency anxiety, and replace AI-powered
translation with Google Translate (MyMemory API) to reduce token usage.

## Changes

### 1. AI Chat Screen — AppBar Cleanup

**Remove:**
- Status dot (green/orange) indicating AI configuration state
- "Online" / "Setup Required" text
- AI model name display (e.g. "gpt-4o-mini")
- Settings gear icon (navigates to SettingsScreen)

**Keep:**
- Robot icon (smart_toy_rounded)
- "Keshab" title text
- Tools PopupMenuButton (grammar mode, voice mode)
- Chat History button
- New Chat button

### 2. AI Chat Screen — Greeting Message

- Remove all API key setup instructions from the greeting
- Show a warm welcome greeting unconditionally
- No mention of configuration or setup

### 3. AI Chat Screen — API-Unavailable Behavior

- AppBar shows NO persistent status indicator
- When user sends a message AND AI call fails:
  - Show an AI-side message bubble in the chat with text: `"AI service not available"`
  - It appears as a regular AI message (isMe: false)
- No other fallback UI (no snackbar, no dialog, no banner, no status text)

### 4. Translation — Google Translate (MyMemory API)

**Current:** `_translateToBangla()` calls `AIService().sendMessage()` with a prompt.

**New:** Create `TranslationService` that calls MyMemory API:

```
GET https://api.mymemory.translated.net/get?q={text}&langpair=en|bn
```

- No API key required
- Uses existing `http` package
- Returns translated text directly
- Replace AI call in `_translateToBangla()` only
- Banglish Translator keeps AI (grammar analysis features need it)

### 5. Settings Screen

- Settings screen remains in the app (accessible via deep navigation)
- No direct shortcut from AI Chat AppBar

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/ai_teacher/screens/ai_chat_screen.dart` | AppBar cleanup, greeting update, import Google Translate service, replace `_translateToBangla()` |
| `lib/services/translation_service.dart` | **New file** — MyMemory API wrapper |
| `lib/features/translator/screens/banglish_translator_screen.dart` | Improve existing AI-based translation (quality polish) |

## Architecture

```
User taps translate button
  → ai_chat_screen._translateToBangla()
    → TranslationService.translate(text, from: 'en', to: 'bn')
      → http.get(MyMemory API)
      → parse JSON response
      → return translated text
    → update message widget with translated text
```

## Error Handling

- MyMemory API failure → show "(Could not translate. Please try again.)" (existing pattern)
- AI service unavailable → inline "AI service not available" when user sends a message
