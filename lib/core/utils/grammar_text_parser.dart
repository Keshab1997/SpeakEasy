import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A utility class that parses grammar text and returns richly formatted
/// [InlineSpan] trees with keyword highlighting, code formatting, and more.
class GrammarTextParser {
  GrammarTextParser._();

  // ── Grammar keyword sets ──────────────────────────────────────────────

  /// Key English grammar terms (+ common Bangla equivalents).
  /// The map value is the highlight [Color].
  static final Map<RegExp, Color> _keywordMap = {
    // Parts of Speech
    RegExp(r'\b(noun|nouns|pronoun|pronouns|verb|verbs|adverb|adverbs|adjective|adjectives|preposition|prepositions|conjunction|conjunctions|interjection|interjections|article|articles|determiner|determiners)\b',
        caseSensitive: false): AppColors.primary,
    // Core grammar concepts
    RegExp(r'\b(vowel|vowels|consonant|consonants|alphabet|letter|letters|word|words|sentence|sentences|phrase|phrases|clause|clauses|tense|tenses|voice|mood|subject|predicate|object|complement|modifier|modifiers)\b',
        caseSensitive: false): const Color(0xFF7C3AED), // Purple
    // Verb types
    RegExp(r'\b(transitive|intransitive|linking verb|auxiliary|modal|modal verb|infinitive|gerund|participle|past participle|present participle)\b',
        caseSensitive: false): const Color(0xFF0891B2), // Cyan
    // Sentence types & grammar rules
    RegExp(r'\b(simple|compound|complex|declarative|interrogative|imperative|exclamatory|positive|comparative|superlative|active|passive|direct|indirect|reported)\b',
        caseSensitive: false): const Color(0xFFD97706), // Amber
    // Count / quantity
    RegExp(r'\b(singular|plural|countable|uncountable|countable noun|uncountable noun|quantifier|quantifiers)\b',
        caseSensitive: false): const Color(0xFF059669), // Green
    // Key structural terms
    RegExp(r'\b(capital|uppercase|lowercase|prefix|suffix|root|stem|silent letter|spelling|punctuation|capitalization)\b',
        caseSensitive: false): const Color(0xFFDC2626), // Red
  };

  /// Bangla grammar keywords to highlight.
  static final Map<RegExp, Color> _banglaKeywordMap = {
    RegExp(r'(বিশেষ্য|সর্বনাম|ক্রিয়া|ক্রিয়া|বিশেষণ|ক্রিয়াবিশেষণ|ক্রিয়া বিশেষণ|অব্যয়|অব্যয়|পদ|ধাতু|প্রকৃতি|প্রত্য�়|প্রত্যয়|সমাস|কারক|বিভক্তি|বচন|লিঙ্গ|পুরুষ|কাল|ধ্বনি|স্বরধ্বনি|ব্যঞ্জনধ্বনি|বর্ণ|বর্ণমালা|শব্দ|বাক্য|বাক্যাংশ|খণ্ডবাক্য|সম্প্রসারণ|উপসর্গ|অনুসর্গ|যতি|ছন্দ|অলংকার)',
        caseSensitive: false): AppColors.primary,
    RegExp(r'(সাপেক্ষ|অস্তিবাচক|নেতিবাচক|ঘোষক|প্রশ্নবোধক|আদেশবোধক|বিস্ময়সূচক|বিস্ময়সূচক|সরল|জটিল|যৌগিক|কর্তৃবাচ্য|কর্মবাচ্য|ভাববাচ্য|সমুচ্চয়ী|সমুচ্চয়ী|অধীনস্থ|সম্বন্ধীয়|সম্বন্ধীয়)',
        caseSensitive: false): const Color(0xFF7C3AED),
    RegExp(r'(একবচন|বহুবচন|গণনাযোগ্য|অগণনাযোগ্য|পুরুষ|উত্তম|মধ্যম|প্রথম|দ্বিতীয়|তৃতীয়)',
        caseSensitive: false): const Color(0xFF059669),
  };

  /// Regex that matches any of the English keywords.
  static final RegExp _englishKeywordPattern =
      RegExp(_keywordMap.keys.map((re) => '(?:${re.pattern})').join('|'),
          caseSensitive: false);

  /// Regex that matches any of the Bangla keywords.
  static final RegExp _banglaKeywordPattern =
      RegExp(_banglaKeywordMap.keys.map((re) => '(?:${re.pattern})').join('|'),
          caseSensitive: false);

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns a [TextSpan] with highlighted English grammar keywords.
  static InlineSpan highlightEnglish(String text, {TextStyle? baseStyle}) {
    return _highlight(text, _englishKeywordPattern, _keywordMap,
        baseStyle: baseStyle);
  }

  /// Returns a [TextSpan] with highlighted Bangla grammar keywords.
  static InlineSpan highlightBangla(String text, {TextStyle? baseStyle}) {
    return _highlight(text, _banglaKeywordPattern, _banglaKeywordMap,
        baseStyle: baseStyle);
  }

  /// Auto-detects whether the text is Bangla or English and highlights.
  static InlineSpan highlightAuto(String text, {TextStyle? baseStyle}) {
    final hasBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(text);
    if (hasBangla) {
      // Bangla text – highlight Bangla keywords
      return highlightBangla(text, baseStyle: baseStyle);
    }
    return highlightEnglish(text, baseStyle: baseStyle);
  }

  /// Returns a syntax-highlighted [TextSpan] for a grammar formula.
  ///
  /// Colour scheme:
  ///   - structural keywords (Sentence, structure, etc.) → blue
  ///   - grammatical placeholders (Subject, Verb, Object, etc.) → teal
  ///   - punctuation / arrows  → amber
  ///   - example words (quotations) → green italic
  static InlineSpan highlightFormula(String text, {TextStyle? baseStyle}) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    final defaultStyle =
        baseStyle ?? const TextStyle(fontFamily: 'monospace', fontSize: 14);

    void flushBuffer({TextStyle? override}) {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(
        text: buffer.toString(),
        style: override ?? defaultStyle,
      ));
      buffer.clear();
    }

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];

      // 1. Quoted example words → green italic
      if (ch == "'" || ch == '"' || ch == '‘' || ch == '“') {
        flushBuffer();
        buffer.write(ch);
        i++;
        while (i < text.length &&
            !(text[i] == "'" || text[i] == '"' || text[i] == '’' || text[i] == '”')) {
          buffer.write(text[i]);
          i++;
        }
        if (i < text.length) buffer.write(text[i]);
        spans.add(TextSpan(
          text: buffer.toString(),
          style: defaultStyle.copyWith(
            color: const Color(0xFF059669),
            fontStyle: FontStyle.italic,
          ),
        ));
        buffer.clear();
        continue;
      }

      // 2. Structural keywords (Sentence, Structure, Pattern, Rule, Formula)
      if (_isStructuralKeyword(text, i)) {
        flushBuffer();
        final keyword = _extractWord(text, i);
        spans.add(TextSpan(
          text: keyword,
          style: defaultStyle.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ));
        i += keyword.length - 1;
        continue;
      }

      // 3. Grammatical placeholders (Subject, Verb, Object, Noun, etc.)
      if (_isPlaceholder(text, i)) {
        flushBuffer();
        final placeholder = _extractWord(text, i);
        spans.add(TextSpan(
          text: placeholder,
          style: defaultStyle.copyWith(
            color: const Color(0xFF0891B2),
            fontWeight: FontWeight.w600,
          ),
        ));
        i += placeholder.length - 1;
        continue;
      }

      // 4. Arrows, parentheses, colons → amber
      if (_isPunctuation(ch)) {
        flushBuffer();
        spans.add(TextSpan(
          text: ch,
          style: defaultStyle.copyWith(
            color: const Color(0xFFD97706),
            fontWeight: FontWeight.bold,
          ),
        ));
        continue;
      }

      buffer.write(ch);
    }

    flushBuffer();
    return TextSpan(children: spans);
  }

  /// Builds a list of [Widget]s for grammar rules with numbered badges.
  static List<Widget> buildRuleWidgets(
    List<String> rules, {
    required BuildContext context,
    bool isDark = false,
  }) {
    final theme = Theme.of(context);
    return List.generate(rules.length, (index) {
      final rule = rules[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GrammarRichText(
                text: rule,
                baseStyle: theme.textTheme.bodyMedium
                    ?.copyWith(height: 1.6),
                isAuto: true,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────

  static InlineSpan _highlight(
    String text,
    RegExp pattern,
    Map<RegExp, Color> colorMap, {
    TextStyle? baseStyle,
  }) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // The matched keyword
      final keyword = match.group(0)!;
      Color? color;
      for (final entry in colorMap.entries) {
        if (entry.key.hasMatch(keyword)) {
          color = entry.value;
          break;
        }
      }

      spans.add(TextSpan(
        text: keyword,
        style: baseStyle?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              backgroundColor: color?.withOpacity(0.08),
            ) ??
            TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              backgroundColor: color?.withOpacity(0.08),
            ),
      ));

      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  static bool _isStructuralKeyword(String text, int index) {
    const keywords = [
      'Sentence', 'sentences', 'Structure', 'structure',
      'Pattern', 'pattern', 'Rule', 'rule', 'Formula', 'formula',
      'Example', 'examples', 'Note', 'note',
    ];
    for (final kw in keywords) {
      if (text.length >= index + kw.length &&
          text.substring(index, index + kw.length) == kw) {
        return true;
      }
    }
    return false;
  }

  static bool _isPlaceholder(String text, int index) {
    const placeholders = [
      'Subject', 'subject', 'Verb', 'verb',
      'Object', 'object',
      'Noun', 'noun',
      'Pronoun', 'pronoun',
      'Adjective', 'adjective',
      'Adverb', 'adverb',
      'Preposition', 'preposition',
      'Conjunction', 'conjunction',
      'Interjection', 'interjection',
      'Article', 'article',
      'Determiner', 'determiner',
      'Complement', 'complement',
      'Modifier', 'modifier',
      'Phrase', 'phrase',
      'Clause', 'clause',
      'Герундий', 'Infinitive', 'infinitive',
      'Participle', 'participle',
      'Tense', 'tense',
      'Auxiliary', 'auxiliary',
      'Modal', 'modal',
    ];
    for (final ph in placeholders) {
      if (text.length >= index + ph.length &&
          text.substring(index, index + ph.length) == ph) {
        return true;
      }
    }
    return false;
  }

  static bool _isPunctuation(String ch) {
    return '→←(){}[]:;.,-—…!?|/\\+='.contains(ch);
  }

  static String _extractWord(String text, int start) {
    final buf = StringBuffer();
    for (int i = start; i < text.length; i++) {
      if (RegExp(r'[a-zA-Z]').hasMatch(text[i])) {
        buf.write(text[i]);
      } else {
        break;
      }
    }
    return buf.toString();
  }
}

/// A convenience [StatelessWidget] that renders grammar text with
/// auto-highlighted keywords using [GrammarTextParser].
class _GrammarRichText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final bool isAuto;

  const _GrammarRichText({
    required this.text,
    this.baseStyle,
    this.isAuto = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: isAuto
          ? GrammarTextParser.highlightAuto(text, baseStyle: baseStyle)
          : GrammarTextParser.highlightEnglish(text, baseStyle: baseStyle),
    );
  }
}

/// Public widget for rendering highlighted grammar text.
class GrammarRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const GrammarRichText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: GrammarTextParser.highlightAuto(text, baseStyle: style),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

/// Public widget for rendering a highlighted grammar formula.
class FormulaRichText extends StatelessWidget {
  final String formula;
  final TextStyle? style;

  const FormulaRichText({
    super.key,
    required this.formula,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: GrammarTextParser.highlightFormula(formula, baseStyle: style),
    );
  }
}
