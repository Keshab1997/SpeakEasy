import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vocabulary_chapter_model.dart';
import '../models/grammar_chapter_model.dart';

/// Service to seed Firestore collections with vocabulary and grammar data
/// from local JSON assets. This should be triggered from the admin panel
/// to populate the following collections:
///   - content_vocabulary_chapters (chapter metadata)
///   - content_vocabulary_words (individual words per chapter)
///   - content_grammar_chapters (grammar chapter content in markdown)
///   - app_config (single document "daily_word_config")
class FirestoreSeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Manifest containing all vocabulary chapter file paths
  static const String _vocabularyManifestPath =
      'assets/json/vocabulary_manifest.json';

  /// Base path prefix to strip from manifest paths
  static const String _vocabularyBasePath = 'assets/json/vocabulary/';

  /// Seeds all collections: vocabulary chapters, vocabulary words,
  /// grammar chapters, and app config.
  Future<SeedResult> seedAll({
    required void Function(String message) onProgress,
  }) async {
    final result = SeedResult();

    try {
      onProgress('📖 Reading vocabulary data...');
      final vocabResult = await _seedVocabulary(onProgress: onProgress);
      result.vocabularyChapters = vocabResult.chapters;
      result.vocabularyWords = vocabResult.words;

      onProgress('📚 Reading grammar data...');
      final grammarResult = await _seedGrammar(onProgress: onProgress);
      result.grammarChapters = grammarResult;

      onProgress('⚙️  Setting app config...');
      await _seedAppConfig(onProgress: onProgress);

      onProgress('✅ All collections seeded successfully!');
    } catch (e) {
      onProgress('❌ Error: $e');
      result.error = e.toString();
    }

    return result;
  }

  /// Seeds the content_vocabulary_chapters and content_vocabulary_words collections.
  Future<_VocabSeedResult> _seedVocabulary({
    required void Function(String message) onProgress,
  }) async {
    int chapters = 0;
    int words = 0;

    // Load the manifest to get all vocabulary chapter file paths
    final manifestJson = await rootBundle.loadString(_vocabularyManifestPath);
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final paths = (manifest['paths'] as List<dynamic>).cast<String>();

    // Get or create a batch for atomic writes (max 500 operations per batch)
    WriteBatch? currentBatch;
    int batchOps = 0;

    void initBatch() {
      if (currentBatch == null) {
        currentBatch = _firestore.batch();
        batchOps = 0;
      }
    }

    Future<void> commitBatch() async {
      if (currentBatch != null && batchOps > 0) {
        await currentBatch!.commit();
        onProgress('   ⏳ Committed $batchOps operations...');
        currentBatch = null;
        batchOps = 0;
      }
    }

    for (final path in paths) {
      final jsonString = await rootBundle.loadString(path);
      final chapterData = jsonDecode(jsonString) as Map<String, dynamic>;

      final chapter = VocabularyChapter.fromJson(chapterData);

      // Determine the level from the path
      final relativePath = path.replaceFirst(_vocabularyBasePath, '');
      final level = relativePath.split('/').first;

      // --- Seed content_vocabulary_chapters ---
      final chapterDocRef = _firestore
          .collection('content_vocabulary_chapters')
          .doc(); // auto-generated ID

      initBatch();
      currentBatch!.set(chapterDocRef, {
        'chapterNumber': chapter.chapter,
        'title': chapter.title,
        'level': level,
      });
      batchOps++;
      chapters++;

      // --- Seed content_vocabulary_words ---
      for (final word in chapter.words) {
        final wordDocRef = _firestore
            .collection('content_vocabulary_words')
            .doc(); // auto-generated ID

        initBatch();
        currentBatch!.set(wordDocRef, {
          'chapterId': chapterDocRef.id,
          'word': word.word,
          'meaning': word.meaning,
          'banglaMeaning': word.banglaMeaning,
          'pronunciation': word.pronunciation,
          'exampleSentence': word.exampleSentence,
        });
        batchOps++;
        words++;

        // Commit batch if we're approaching the 500 operation limit
        if (batchOps >= 400) {
          await commitBatch();
        }
      }

      onProgress(
          '   ✅ Chapter $chapters: "${chapter.title}" ($level) - ${chapter.words.length} words');

      // Commit batch after each chapter to keep things manageable
      await commitBatch();
    }

    // Commit any remaining batch
    await commitBatch();

    return _VocabSeedResult(chapters: chapters, words: words);
  }

  /// Seeds the content_grammar_chapters collection.
  /// Converts the structured grammar JSON into markdown content.
  Future<int> _seedGrammar({
    required void Function(String message) onProgress,
  }) async {
    int chapters = 0;
    const grammarDir = 'assets/json/grammar/';

    WriteBatch? currentBatch;
    int batchOps = 0;

    void initBatch() {
      if (currentBatch == null) {
        currentBatch = _firestore.batch();
        batchOps = 0;
      }
    }

    Future<void> commitBatch() async {
      if (currentBatch != null && batchOps > 0) {
        await currentBatch!.commit();
        currentBatch = null;
        batchOps = 0;
      }
    }

    final List<String> grammarFileNames = [
      'chapter_01_alphabet',
      'chapter_02_word',
      'chapter_03_sentence',
      'chapter_04_parts_of_speech',
      'chapter_05_noun',
      'chapter_06_pronoun',
      'chapter_07_adjective',
      'chapter_08_verb',
      'chapter_09_adverb',
      'chapter_10_preposition',
      'chapter_11_conjunction',
      'chapter_12_article',
      'chapter_13_determiners',
      'chapter_14_quantifiers',
      'chapter_15_numbers',
      'chapter_16_gender',
      'chapter_17_person',
      'chapter_18_voice',
      'chapter_19_punctuation_marks',
      'chapter_20_capitalization_rules',
      'chapter_21_introduction_to_tense',
      'chapter_22_subject_and_predicate',
      'chapter_23_subject-verb_agreement',
      'chapter_24_types_of_sentences',
      'chapter_25_negative_sentences',
      'chapter_26_wh_questions',
      'chapter_27_tag_questions',
      'chapter_28_there_and_it',
      'chapter_29_modal_verbs',
      'chapter_30_infinitive',
      'chapter_31_gerund',
      'chapter_32_participle',
      'chapter_33_phrases',
      'chapter_34_clauses',
      'chapter_35_phrase_vs_clause',
      'chapter_36_simple_sentence',
      'chapter_37_compound_sentence',
      'chapter_38_complex_sentence',
      'chapter_39_transformation_of_sentences',
      'chapter_40_degree_change',
      'chapter_41_affirmative_and_negative_transformation',
      'chapter_42_assertive_and_interrogative_transformation',
      'chapter_43_exclamatory_transformation',
      'chapter_44_active_voice',
      'chapter_45_passive_voice',
      'chapter_46_direct_speech',
      'chapter_47_indirect_speech',
      'chapter_48_conditional_sentences',
      'chapter_49_comparison',
      'chapter_50_parallelism',
      'chapter_51_advanced_modals',
      'chapter_52_causative_verbs',
      'chapter_53_inversion',
      'chapter_54_emphasis',
      'chapter_55_ellipsis',
      'chapter_56_relative_pronouns',
      'chapter_57_relative_clauses',
      'chapter_58_reported_speech',
      'chapter_59_subjunctive_mood',
      'chapter_60_advanced_conditionals',
      'chapter_61_complex_structures',
      'chapter_62_nominalization',
      'chapter_63_formal_and_informal_english',
      'chapter_64_common_grammar_mistakes',
      'chapter_65_confusing_words',
      'chapter_66_idiomatic_expressions',
      'chapter_67_phrasal_verbs',
      'chapter_68_collocations',
      'chapter_69_sentence_patterns',
      'chapter_70_advanced_writing_structures',
    ];

    for (final fileName in grammarFileNames) {
      final path = '$grammarDir$fileName.json';

      try {
        final jsonString = await rootBundle.loadString(path);
        final chapterData = jsonDecode(jsonString) as Map<String, dynamic>;
        final chapter = GrammarChapter.fromJson(chapterData);

        // Generate markdown content from the structured topics
        final markdownContent = _generateGrammarMarkdown(chapter);

        initBatch();
        final docRef = _firestore
            .collection('content_grammar_chapters')
            .doc(); // auto-generated ID
        currentBatch!.set(docRef, {
          'chapterNumber': chapter.chapter,
          'title': chapter.title,
          'content': markdownContent,
        });
        batchOps++;
        chapters++;

        onProgress('   ✅ Grammar Chapter $chapters: "${chapter.title}"');

        if (batchOps >= 400) {
          await commitBatch();
        }
      } catch (e) {
        onProgress('   ⚠️  Could not load $path: $e');
      }
    }

    await commitBatch();

    return chapters;
  }

  /// Generates markdown content from a GrammarChapter's structured topics.
  String _generateGrammarMarkdown(GrammarChapter chapter) {
    final buffer = StringBuffer();

    // Chapter header
    buffer.writeln('# ${chapter.title}');
    buffer.writeln();
    buffer.writeln('**Level:** ${chapter.level}');
    buffer.writeln();

    if (chapter.description.isNotEmpty) {
      buffer.writeln(chapter.description);
      buffer.writeln();
    }

    if (chapter.banglaDescription.isNotEmpty) {
      buffer.writeln('> ${chapter.banglaDescription}');
      buffer.writeln();
    }

    // Topics
    for (int i = 0; i < chapter.topics.length; i++) {
      final topic = chapter.topics[i];
      buffer.writeln('## ${i + 1}. ${topic.name}');
      buffer.writeln();

      if (topic.banglaName.isNotEmpty) {
        buffer.writeln('*(${topic.banglaName})*');
        buffer.writeln();
      }

      if (topic.definition.isNotEmpty) {
        buffer.writeln('**Definition:** ${topic.definition}');
        buffer.writeln();
      }

      if (topic.banglaDefinition.isNotEmpty) {
        buffer.writeln('> ${topic.banglaDefinition}');
        buffer.writeln();
      }

      if (topic.formula.isNotEmpty) {
        buffer.writeln('```');
        buffer.writeln(topic.formula);
        buffer.writeln('```');
        buffer.writeln();
      }

      if (topic.rules.isNotEmpty) {
        buffer.writeln('### Rules');
        for (final rule in topic.rules) {
          buffer.writeln('- $rule');
        }
        buffer.writeln();
      }

      if (topic.examples.isNotEmpty) {
        buffer.writeln('### Examples');
        buffer.writeln();
        buffer.writeln('| English | Bangla |');
        buffer.writeln('|---------|--------|');
        for (final example in topic.examples) {
          buffer.writeln('| ${example.en} | ${example.bn} |');
        }
        buffer.writeln();
      }

      if (topic.tips.isNotEmpty) {
        buffer.writeln('💡 **Tip:** ${topic.tips}');
        buffer.writeln();
      }
    }

    // Common Mistakes
    if (chapter.commonMistakes.isNotEmpty) {
      buffer.writeln('---');
      buffer.writeln('## Common Mistakes');
      buffer.writeln();

      for (int i = 0; i < chapter.commonMistakes.length; i++) {
        final mistake = chapter.commonMistakes[i];
        buffer.writeln('### ❌ Mistake ${i + 1}');
        buffer.writeln();
        buffer.writeln('- **Wrong:** ${mistake.wrong}');
        buffer.writeln('- **Correct:** ${mistake.correct}');
        buffer.writeln('- **Explanation:** ${mistake.explanation}');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Seeds the app_config collection with the daily_word_config document.
  Future<void> _seedAppConfig({
    required void Function(String message) onProgress,
  }) async {
    final docRef = _firestore
        .collection('app_config')
        .doc('daily_word_config');

    // First check if it already exists
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      onProgress('   ⚠️  daily_word_config already exists, skipping...');
      return;
    }

    await docRef.set({
      'activeChapterId': '',
    });

    onProgress('   ✅ Created daily_word_config document');
  }
}

/// Result of the seed operation
class SeedResult {
  int vocabularyChapters = 0;
  int vocabularyWords = 0;
  int grammarChapters = 0;
  String? error;

  bool get isSuccess => error == null;

  @override
  String toString() {
    if (error != null) {
      return '❌ Seed failed: $error';
    }
    return '''
✅ Seeding completed successfully!
   - Vocabulary Chapters: $vocabularyChapters
   - Vocabulary Words: $vocabularyWords
   - Grammar Chapters: $grammarChapters
   - App Config: Created
''';
  }
}

class _VocabSeedResult {
  final int chapters;
  final int words;

  const _VocabSeedResult({required this.chapters, required this.words});
}