# Fix word_match
sed -i '' "s/gameMode: 'word_match'/gameMode: 'wordMatch'/g" lib/features/game/screens/modes/word_match_mode.dart
# Fix quick_quiz
sed -i '' "s/gameMode: 'quick_quiz'/gameMode: 'quickQuiz'/g" lib/features/game/screens/modes/quick_quiz_mode.dart
# Fix fill_in_blanks
sed -i '' "s/gameMode: 'fill_in_blanks'/gameMode: 'fillInBlank'/g" lib/features/game/screens/modes/fill_in_blanks_mode.dart
# Fix sentence_builder
sed -i '' "s/gameMode: 'sentence_builder'/gameMode: 'sentenceBuilder'/g" lib/features/game/screens/modes/sentence_builder_mode.dart
# Fix grammar_detective
sed -i '' "s/gameMode: 'grammar_detective'/gameMode: 'grammarDetective'/g" lib/features/game/screens/modes/grammar_detective_mode.dart
# Fix verb_learning
sed -i '' "s/gameMode: 'verb_learning'/gameMode: 'verbLearning'/g" lib/features/game/screens/modes/verb_learning_mode.dart
# Fix bangla_to_english
sed -i '' "s/gameMode: 'bangla_to_english'/gameMode: 'banglaToEnglish'/g" lib/features/game/screens/modes/bangla_to_english_mode.dart
# Fix story_completion
sed -i '' "s/gameMode: 'story_completion'/gameMode: 'storyCompletion'/g" lib/features/game/screens/modes/story_completion_mode.dart
# Fix Flashcards
sed -i '' "s/gameMode: 'Flashcards'/gameMode: 'flashcard'/g" lib/features/game/screens/modes/flashcard_mode.dart

# Also need to fix ResultScreen _retryGame logic which uses gameMode
sed -i '' "s/widget.gameMode == 'word_match'/widget.gameMode == 'wordMatch'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'quick_quiz'/widget.gameMode == 'quickQuiz'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'fill_in_blanks'/widget.gameMode == 'fillInBlank'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'sentence_builder'/widget.gameMode == 'sentenceBuilder'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'grammar_detective'/widget.gameMode == 'grammarDetective'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'verb_learning'/widget.gameMode == 'verbLearning'/g" lib/features/game/screens/result_screen.dart
sed -i '' "s/widget.gameMode == 'flashcard'/widget.gameMode == 'flashcard'/g" lib/features/game/screens/result_screen.dart

