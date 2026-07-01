---
title: Mock Test Question Palette Design
summary: Add question palette bottom sheet to MockTestQuizScreen for quick navigation between questions
tags: [mock-test, quiz, ui, navigation]
related: [.brv/context-tree/features/mock_tests/mock_test_feature.md]
keywords: [question-palette, bottom-sheet, flutter]
---

# Mock Test Question Palette Design

## Overview

Add a question palette bottom sheet to MockTestQuizScreen that allows users to navigate to any question via a grid view. The palette shows question status (answered/unanswered/current) and provides smooth animated transitions.

## Current State

- MockTestQuizScreen currently uses Next/Previous buttons only
- 20 questions per test with shuffled options
- `_answers` map tracks answered questions (questionIndex -> shuffledOptionIndex)

## Design

### Components

#### 1. QuestionPaletteBottomSheet Widget (new file)

Location: `lib/features/mock_test/widgets/question_palette_bottom_sheet.dart`

```dart
class QuestionPaletteBottomSheet extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestion;
  final Map<int, int> answers;
  final ValueChanged<int> onQuestionSelected;
  
  // Visual states:
  // - Answered: filled AppColors.primary circle with white number
  // - Unanswered: outlined grey circle
  // - Current: thick primary border + scale up 1.1x
}
```

**Layout:**
- Grid: 4 columns × 5 rows (20 questions)
- Each cell: CircleAvatar with question number
- Header: "Questions (X/Y answered)"
- Close button (X icon) at top right

#### 2. AppBar Integration

Location: `lib/features/mock_test/screens/mock_test_quiz_screen.dart`

Add to AppBar actions:
```dart
IconButton(
  icon: const Icon(Icons.grid_view_rounded),
  onPressed: () => showModalBottomSheet(...),
)
```

#### 3. Smooth Transition

Uses `PageController.animateToPage()` for smooth navigation:
```dart
final _pageController = PageController();

void _goToQuestion(int index) {
  _pageController.animateToPage(
    index,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
```

### Data Flow

```
User taps grid icon
    ↓
showModalBottomSheet opens QuestionPaletteBottomSheet
    ↓
User selects question number
    ↓
onQuestionSelected callback triggers
    ↓
animateToPage(index) with smooth transition
    ↓
_currentQuestion updates, UI rebuilds
```

### Visual States

| State | Color | Border | Size |
|-------|-------|--------|------|
| Answered | AppColors.primary (filled) | none | normal |
| Unanswered | transparent (outlined) | grey | normal |
| Current | transparent (outlined) | AppColors.primary thick (3px) | 1.1x scale |

## Implementation Notes

- Follow existing code patterns in mock_test directory
- Use Riverpod `ref.read()` for state access
- Match existing theme: dark mode support via `isDark` check
- Bottom sheet radius: 20px top corners
- Answered count shown in header

## Files Changed

- NEW: `lib/features/mock_test/widgets/question_palette_bottom_sheet.dart`
- MODIFY: `lib/features/mock_test/screens/mock_test_quiz_screen.dart` (AppBar + callback)

## Success Criteria

- [ ] Grid icon appears in AppBar
- [ ] Bottom sheet opens with 4×5 grid
- [ ] Question states visually distinct
- [ ] Smooth animation when jumping to question
- [ ] Answered count updates in real-time
- [ ] Works with shuffle logic intact