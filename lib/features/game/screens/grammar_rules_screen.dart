import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'question_screen.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class TenseRule {
  final int step;
  final String title;
  final String banglaTitle;
  final String icon;
  final String color;
  final String explanation;
  final List<String> points;
  final List<Map<String, String>> examples;

  TenseRule({
    required this.step,
    required this.title,
    required this.banglaTitle,
    required this.icon,
    required this.color,
    required this.explanation,
    required this.points,
    required this.examples,
  });

  factory TenseRule.fromJson(Map<String, dynamic> json) {
    return TenseRule(
      step: json['step'] ?? 0,
      title: json['title'] ?? '',
      banglaTitle: json['banglaTitle'] ?? '',
      icon: json['icon'] ?? '',
      color: json['color'] ?? '#2563EB',
      explanation: json['explanation'] ?? '',
      points: List<String>.from(json['points'] ?? []),
      examples: (json['examples'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class TenseRulesData {
  final String tenseId;
  final String tenseName;
  final String banglaName;
  final String color;
  final String shortDescription;
  final Map<String, String> structure;
  final List<TenseRule> rules;
  final Map<String, dynamic> quickSummary;

  TenseRulesData({
    required this.tenseId,
    required this.tenseName,
    required this.banglaName,
    required this.color,
    required this.shortDescription,
    required this.structure,
    required this.rules,
    required this.quickSummary,
  });

  factory TenseRulesData.fromJson(Map<String, dynamic> json) {
    return TenseRulesData(
      tenseId: json['tenseId'] ?? '',
      tenseName: json['tenseName'] ?? '',
      banglaName: json['banglaName'] ?? '',
      color: json['color'] ?? '#2563EB',
      shortDescription: json['shortDescription'] ?? '',
      structure: Map<String, String>.from(json['structure'] ?? {}),
      rules: (json['rules'] as List<dynamic>?)
              ?.map((r) => TenseRule.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      quickSummary: json['quickSummary'] ?? {},
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

Color _parseHexColor(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class GrammarRulesScreen extends ConsumerStatefulWidget {
  final String tenseId;
  final String tenseName;
  final String rulesAssetPath;

  const GrammarRulesScreen({
    super.key,
    required this.tenseId,
    required this.tenseName,
    required this.rulesAssetPath,
  });

  @override
  ConsumerState<GrammarRulesScreen> createState() => _GrammarRulesScreenState();
}

class _GrammarRulesScreenState extends ConsumerState<GrammarRulesScreen>
    with TickerProviderStateMixin {
  TenseRulesData? _rulesData;
  bool _isLoading = true;
  int _currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showQuickSummary = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _loadRules();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    try {
      final jsonStr = await rootBundle.loadString(widget.rulesAssetPath);
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _rulesData = TenseRulesData.fromJson(jsonData);
        _isLoading = false;
      });
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _goToNextStep() {
    if (_rulesData == null) return;
    if (_currentStep < _rulesData!.rules.length - 1) {
      setState(() => _currentStep++);
      _slideController.reset();
      _slideController.forward();
    } else {
      setState(() => _showQuickSummary = true);
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _goToPrevStep() {
    if (_showQuickSummary) {
      setState(() => _showQuickSummary = false);
      _slideController.reset();
      _slideController.forward();
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _startPractice() {
    ref.read(soundProvider.notifier).playButtonTap();
    ref.read(gameProvider.notifier).loadQuestions(
      tenseType: widget.tenseId,
      limit: 15,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuestionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = _rulesData != null
        ? _parseHexColor(_rulesData!.color)
        : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _rulesData == null
              ? _buildErrorState(isDark)
              : _buildContent(isDark, themeColor),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Rules লোড করা যায়নি', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ফিরে যাও'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, Color themeColor) {
    final data = _rulesData!;
    final totalSteps = data.rules.length + 1; // +1 for summary
    final currentDisplay = _showQuickSummary ? totalSteps : _currentStep + 1;

    return CustomScrollView(
      slivers: [
        // ── AppBar ───────────────────────────────────────────────
        SliverAppBar(
	          expandedHeight: 210,
          pinned: true,
          backgroundColor: themeColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeColor,
                    themeColor.withOpacity(0.7),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data.banglaName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.tenseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.shortDescription,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Body ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress Indicator
                _buildProgressBar(currentDisplay, totalSteps, themeColor, isDark),
                const SizedBox(height: 20),

                // Structure Card (always visible at top)
                _buildStructureCard(data, themeColor, isDark),
                const SizedBox(height: 20),

                // Step Content
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _showQuickSummary
                        ? _buildQuickSummary(data, themeColor, isDark)
                        : _buildRuleStep(
                            data.rules[_currentStep], themeColor, isDark),
                  ),
                ),

                const SizedBox(height: 24),

                // Navigation Buttons
                _buildNavigationButtons(currentDisplay, totalSteps, themeColor, isDark),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int current, int total, Color themeColor, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ধাপ $current / $total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: themeColor,
              ),
            ),
            Text(
              '${((current / total) * 100).toInt()}% সম্পন্ন',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: current / total,
            backgroundColor: themeColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStructureCard(TenseRulesData data, Color themeColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schema, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'গঠন (Structure)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.structure.entries.map((e) {
            final label = e.key == 'affirmative'
                ? '✅ স্বীকারবাচক'
                : e.key == 'negative'
                    ? '❌ নেতিবাচক'
                    : '❓ প্রশ্নবাচক';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeColor.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRuleStep(TenseRule rule, Color themeColor, bool isDark) {
    final stepColor = _parseHexColor(rule.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [stepColor, stepColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: stepColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${rule.step}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule.banglaTitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Explanation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: stepColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.explanation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Points
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.list_alt, color: stepColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'মূল নিয়মসমূহ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...rule.points.asMap().entries.map((e) {
                final idx = e.key;
                final point = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: stepColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              color: stepColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        if (rule.examples.isNotEmpty) ...[
          const SizedBox(height: 16),

          // Examples
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: stepColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: stepColor.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, color: stepColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'উদাহরণ (Examples)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: stepColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...rule.examples.map((ex) => _buildExampleTile(ex, stepColor, isDark)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExampleTile(Map<String, String> ex, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ex['english'] ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ex['bangla'] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary(TenseRulesData data, Color themeColor, bool isDark) {
    final summary = data.quickSummary;
    final formula = summary['formula'] as String? ?? '';
    final keyPoints = List<String>.from(summary['keyPoints'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'দ্রুত সারসংক্ষেপ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Quick Summary',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Formula Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeColor.withOpacity(0.4), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions, color: themeColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Formula',
                    style: TextStyle(
                      fontSize: 13,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formula,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Key Points
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'মনে রাখার মূল বিষয়',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...keyPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Congratulations
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              Text('🎉', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text(
                'অভিনন্দন! সব নিয়ম পড়া শেষ হয়েছে',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'এখন Practice শুরু করো এবং দেখো কতটুকু শিখেছো!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(
      int current, int total, Color themeColor, bool isDark) {
    final isFirst = current == 1 && !_showQuickSummary;
    final isLast = _showQuickSummary;

    return Column(
      children: [
        if (isLast) ...[
          // Start Practice Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startPractice,
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text(
                'Practice শুরু করো! 🚀',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'পরে Practice করব',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ] else ...[
          Row(
            children: [
              if (!isFirst)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _goToPrevStep,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('আগের ধাপ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (!isFirst) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _goToNextStep,
                  icon: Icon(
                    current == total - 1 ? Icons.auto_awesome : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: Text(
                    current == total - 1 ? 'সারসংক্ষেপ দেখো' : 'পরের ধাপ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Skip to Practice
          TextButton.icon(
            onPressed: _startPractice,
            icon: Icon(Icons.skip_next, color: themeColor, size: 18),
            label: Text(
              'Rules বাদ দিয়ে সরাসরি Practice করো',
              style: TextStyle(
                color: themeColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
