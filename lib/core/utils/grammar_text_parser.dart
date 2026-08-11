import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A utility class that parses grammar text and returns clean [InlineSpan]
/// trees.
///
/// Keyword highlighting is intentionally disabled. Lesson text is rendered as
/// a single unstyled run so:
///  - no colored highlight boxes appear behind words, and
///  - Bengali text keeps its correct ligature/joina shaping (splitting a run
///    into many individually-styled spans breaks Indic glyph shaping and
///    causes broken, overlapped, or oddly-spaced letters).
class GrammarTextParser {
  GrammarTextParser._();

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns a [TextSpan] rendered as one clean run.
  static InlineSpan highlightEnglish(String text, {TextStyle? baseStyle}) {
    return TextSpan(text: text, style: baseStyle);
  }

  /// Same as [highlightEnglish]; kept for API compatibility.
  static InlineSpan highlightBangla(String text, {TextStyle? baseStyle}) {
    return TextSpan(text: text, style: baseStyle);
  }

  /// Same as [highlightEnglish]; kept for API compatibility.
  static InlineSpan highlightAuto(String text, {TextStyle? baseStyle}) {
    return TextSpan(text: text, style: baseStyle);
  }

  /// Returns a plain [TextSpan] for a grammar formula.
  static InlineSpan highlightFormula(String text, {TextStyle? baseStyle}) {
    return TextSpan(
      text: text,
      style: baseStyle ?? const TextStyle(fontSize: 14),
    );
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
}

/// A convenience [StatelessWidget] that renders grammar text via
/// [GrammarTextParser].
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

/// Public widget for rendering grammar text.
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

/// Public widget for rendering a grammar formula.
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