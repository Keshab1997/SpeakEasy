import 'dart:math';
import '../models/grammar_chapter_model.dart';
import '../models/quiz_model.dart';

List<QuestionModel> generateGrammarQuiz(GrammarChapter chapter) {
  final questions = <QuestionModel>[];
  final topics = chapter.topics;
  if (topics.isEmpty) return questions;
  final rng = Random();

  // 1. Name → BanglaName (max 2)
  final shuffledTopics = List.of(topics)..shuffle(rng);
  for (final topic in shuffledTopics.take(min(2, topics.length))) {
    if (topic.banglaName.isEmpty) continue;
    final others = topics
        .where((t) => t.banglaName.isNotEmpty && t.banglaName != topic.banglaName)
        .toList()
      ..shuffle(rng);
    if (others.length < 3) continue;
    final wrong = others.take(3).map((t) => t.banglaName).toList();
    final options = [topic.banglaName, ...wrong]..shuffle(rng);
    final q1 = topic.banglaName.isNotEmpty
        ? "What is the Bangla meaning of '${topic.name}'?\n'${topic.name}' এর বাংলা অর্থ কী?"
        : "What is the Bangla meaning of '${topic.name}'?";
    questions.add(QuestionModel(
      question: q1,
      options: options,
      correctIndex: options.indexOf(topic.banglaName),
    ));
  }

  // 2. Definition → Topic (max 2)
  final defTopics = topics.where((t) => t.definition.isNotEmpty).toList()..shuffle(rng);
  for (final topic in defTopics.take(min(2, defTopics.length))) {
    final others = topics.where((t) => t.name.isNotEmpty && t.name != topic.name).toList()..shuffle(rng);
    if (others.length < 3) continue;
    final wrong = others.take(3).map((t) => t.name).toList();
    final options = [topic.name, ...wrong]..shuffle(rng);
    final q2 = topic.banglaDefinition.isNotEmpty
        ? 'Which topic does this definition belong to?\nএই সংজ্ঞাটি কোন টপিকের?\n\n${topic.definition}\n\nবাংলা: ${topic.banglaDefinition}'
        : 'Which topic does this definition belong to?\n\n${topic.definition}';
    questions.add(QuestionModel(
      question: q2,
      options: options,
      correctIndex: options.indexOf(topic.name),
    ));
  }

  // 3. Example translation (max 3)
  final allExamples = <GrammarExample>[];
  for (final topic in topics) {
    allExamples.addAll(topic.examples);
  }
  allExamples.shuffle(rng);
  for (final ex in allExamples.take(min(3, allExamples.length))) {
    final others = allExamples.where((e) => e.bn != ex.bn).toList()..shuffle(rng);
    if (others.length < 3) continue;
    final wrong = others.take(3).map((e) => e.bn).toList();
    final options = [ex.bn, ...wrong]..shuffle(rng);
    questions.add(QuestionModel(
      question: 'Choose the Bangla translation / বাংলা অনুবাদ নির্বাচন করুন:\n\n"${ex.en}"',
      options: options,
      correctIndex: options.indexOf(ex.bn),
    ));
  }

  // 4. Rule → Topic (max 2)
  final rulePairs = <MapEntry<String, String>>[];
  for (final topic in topics) {
    for (final rule in topic.rules) {
      rulePairs.add(MapEntry(rule, topic.name));
    }
  }
  rulePairs.shuffle(rng);
  for (final pair in rulePairs.take(min(2, rulePairs.length))) {
    final others = topics.where((t) => t.name.isNotEmpty && t.name != pair.value).toList()..shuffle(rng);
    if (others.length < 3) continue;
    final wrong = others.take(3).map((t) => t.name).toList();
    final options = [pair.value, ...wrong]..shuffle(rng);
    questions.add(QuestionModel(
      question: 'Which topic does this rule belong to?\nএই নিয়মটি কোন টপিকের?\n\n"${pair.key}"',
      options: options,
      correctIndex: options.indexOf(pair.value),
    ));
  }

  // 5. Common Mistakes (max 2)
  if (chapter.commonMistakes.length >= 2) {
    final mistakes = List.of(chapter.commonMistakes)..shuffle(rng);
    for (final m in mistakes.take(min(2, mistakes.length))) {
      final others = chapter.commonMistakes
          .where((x) => x.correct != m.correct)
          .toList()
        ..shuffle(rng);
      final wrong = others.take(3).map((x) => x.correct).toList();
      if (wrong.length < 3) continue;
      final options = [m.correct, ...wrong]..shuffle(rng);
      questions.add(QuestionModel(
        question: 'Which sentence is grammatically correct?\nকোন বাক্যটি ব্যাকরণগতভাবে সঠিক?',
        options: options,
        correctIndex: options.indexOf(m.correct),
        explanation: m.explanation,
      ));
    }
  }

  questions.shuffle(rng);
  return questions.take(min(questions.length, 15)).toList();
}
