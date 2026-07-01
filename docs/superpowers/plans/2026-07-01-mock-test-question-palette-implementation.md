# Mock Test Question Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a question palette bottom sheet to MockTestQuizScreen for quick navigation between questions with visual status indicators and smooth animated transitions.

**Architecture:** Create a reusable QuestionPaletteBottomSheet widget that integrates with MockTestQuizScreen via PageController for smooth transitions between questions.

**Tech Stack:** Flutter, Riverpod, Material Design, PageView for smooth transitions

---

### Task 1: Add PageController to MockTestQuizScreen

**Files:**
- Modify: `lib/features/mock_test/screens/mock_test_quiz_screen.dart`

- [ ] **Step 1: Add PageController field**

Add after line 37 (after `_shuffledQuestions` field):
```dart
late final PageController _pageController;
```

- [ ] **Step 2: Initialize PageController in initState**

Replace line 53-57 with:
```dart
@override
void initState() {
  super.initState();
  _shuffledQuestions = [];
  _pageController = PageController();
  _shuffleAllQuestions();
}
```

- [ ] **Step 3: Wrap question content in PageView**

Replace line 105-286 (the Expanded widget containing SingleChildScrollView) with:
```dart
// ── Question Content ──
Expanded(
  child: PageView.builder(
    controller: _pageController,
    itemCount: questions.length,
    onPageChanged: (index) {
      setState(() {
        _currentQuestion = index;
        _selectedAnswer = _answers[index];
      });
    },
    itemBuilder: (context, index) {
      final question = questions[index];
      final shuffled = _shuffledQuestions[index];
      // ... rest of existing question UI code (lines 186-286)
    },
  ),
),
```

- [ ] **Step 4: Update navigation to use PageController**

Replace lines 311-338 (Previous button and Next/Submit button handlers) with:
```dart
// Previous button
if (_currentQuestion > 0)
  TextButton(
    onPressed: _isSubmitting
        ? null
        : () {
            if (_selectedAnswer != null) {
              _answers[_currentQuestion] = _selectedAnswer!;
            }
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
    child: const Text('Previous'),
  )
else
  const SizedBox.shrink(),
```

And replace the Next/Submit button onPressed (lines 331-358):
```dart
onPressed: _selectedAnswer != null && !_isSubmitting
    ? () {
        _answers[_currentQuestion] = _selectedAnswer!;
        if (_currentQuestion < questions.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _submitQuiz();
        }
      }
    : null,
```

- [ ] **Step 5: Dispose PageController**

Add dispose method after build method (around line 367):
```dart
@override
void dispose() {
  _pageController.dispose();
  super.dispose();
}
```

- [ ] **Step 6: Run flutter analyze**

Run: `flutter analyze lib/features/mock_test/screens/mock_test_quiz_screen.dart`
Expected: No errors (may have warnings)

- [ ] **Step 7: Commit**

```bash
git add lib/features/mock_test/screens/mock_test_quiz_screen.dart
git commit -m "refactor(mock_test): add PageController for question navigation"
```

---

### Task 2: Create QuestionPaletteBottomSheet Widget

**Files:**
- Create: `lib/features/mock_test/widgets/question_palette_bottom_sheet.dart`

- [ ] **Step 1: Create widget file**

```dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class QuestionPaletteBottomSheet extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestion;
  final Map<int, int> answers;
  final ValueChanged<int> onQuestionSelected;

  const QuestionPaletteBottomSheet({
    super.key,
    required this.totalQuestions,
    required this.currentQuestion,
    required this.answers,
    required this.onQuestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final answeredCount = answers.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions ($answeredCount/$totalQuestions answered)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: totalQuestions,
              itemBuilder: (context, index) {
                final isAnswered = answers.containsKey(index);
                final isCurrent = index == currentQuestion;

                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onQuestionSelected(index);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedScale(
                    scale: isCurrent ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isAnswered
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight),
                          width: isCurrent ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isAnswered
                                ? Colors.white
                                : (isCurrent
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54)),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/features/mock_test/widgets/question_palette_bottom_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/mock_test/widgets/question_palette_bottom_sheet.dart
git commit -m "feat(mock_test): create question palette bottom sheet widget"
```

---

### Task 3: Integrate Palette with Quiz Screen

**Files:**
- Modify: `lib/features/mock_test/screens/mock_test_quiz_screen.dart`

- [ ] **Step 1: Add import for QuestionPaletteBottomSheet**

Add after line 7:
```dart
import '../../widgets/question_palette_bottom_sheet.dart';
```

- [ ] **Step 2: Add grid icon to AppBar**

Replace lines 110-134 (AppBar definition) with:
```dart
appBar: AppBar(
  title: Text(widget.testTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
  leading: IconButton(
    icon: const Icon(Icons.close_rounded),
    onPressed: _isSubmitting
        ? null
        : () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Leave Test?'),
                content: const Text('Your progress in this attempt will be lost.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue Test')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.grid_view_rounded),
      onPressed: _isSubmitting
          ? null
          : () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => QuestionPaletteBottomSheet(
                  totalQuestions: test.questions.length,
                  currentQuestion: _currentQuestion,
                  answers: _answers,
                  onQuestionSelected: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
    ),
  ],
),
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/mock_test/screens/mock_test_quiz_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/mock_test/screens/mock_test_quiz_screen.dart
git commit -m "feat(mock_test): integrate question palette with quiz screen"
```

---

### Task 4: Test and Verify Implementation

**Files:**
- None (manual testing)

- [ ] **Step 1: Run flutter analyze on entire mock_test directory**

```bash
flutter analyze lib/features/mock_test/
```
Expected: 0 errors

- [ ] **Step 2: Run existing tests**

```bash
flutter test test/
```
Expected: All tests pass

- [ ] **Step 3: Manual testing checklist**

- [ ] Grid icon appears in AppBar (top right)
- [ ] Bottom sheet opens on tap
- [ ] Grid shows 20 questions in 4×5 layout
- [ ] Answered questions show filled primary color
- [ ] Unanswered questions show outlined grey
- [ ] Current question has thick primary border + scale effect
- [ ] Tapping a question navigates smoothly
- [ ] Answered count updates in header

- [ ] **Step 4: Commit**

```bash
git commit -am "test(mock_test): verify question palette implementation"
```