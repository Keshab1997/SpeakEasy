import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/verb_form_model.dart';
import 'verb_form_list_screen.dart';
import 'verb_forms_guide_screen.dart';
import 'verb_form_practice_screen.dart';

class VerbFormsScreen extends StatefulWidget {
  const VerbFormsScreen({super.key});

  @override
  State<VerbFormsScreen> createState() => _VerbFormsScreenState();
}

class _VerbFormsScreenState extends State<VerbFormsScreen> {
  List<VerbFormCategory>? _categories;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await VerbFormCategory.loadAll();
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.transform_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Verb Forms', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Choose a Category',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${_categories!.length} categories — ${_categories!.fold(0, (s, c) => s + c.verbs.length)} verbs',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 16),
                    _buildGuideCard(context),
                    const SizedBox(height: 12),
                    _buildPracticeCard(context),
                    const SizedBox(height: 16),
                    ..._categories!.map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildCategoryCard(context, cat),
                        )),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGuideCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VerbFormsGuideScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.15),
              AppColors.secondary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school_rounded,
                  color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Verb Forms Guide',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text('V1-V5 rules, examples & tips in Bengali',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeCard(BuildContext context) {
    final total = _categories!.fold(0, (s, c) => s + c.verbs.length);
    final hasData = total > 0;
    return GestureDetector(
      onTap: hasData
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      VerbFormPracticeScreen(categories: _categories!)))
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withOpacity(0.2),
              AppColors.error.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.quiz_rounded,
                  color: AppColors.warning, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Practice Quiz',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.warning)),
                  const SizedBox(height: 2),
                  Text(hasData
                      ? 'Multiple choice from $total verbs'
                      : 'Add verbs first to practice',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.warning, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, VerbFormCategory cat) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => VerbFormListScreen(category: cat))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cat.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cat.color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(cat.icon, color: cat.color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cat.color)),
                  const SizedBox(height: 2),
                  Text(cat.subtitle,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${cat.verbs.length}',
                  style: TextStyle(
                      color: cat.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cat.color, size: 22),
          ],
        ),
      ),
    );
  }
}
