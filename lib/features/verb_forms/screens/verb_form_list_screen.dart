import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/verb_form_model.dart';

class VerbFormListScreen extends StatefulWidget {
  final VerbFormCategory category;

  const VerbFormListScreen({super.key, required this.category});

  @override
  State<VerbFormListScreen> createState() => _VerbFormListScreenState();
}

class _VerbFormListScreenState extends State<VerbFormListScreen> {
  List<VerbForm>? _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.category.verbs;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    if (q.isEmpty) {
      setState(() => _filtered = widget.category.verbs);
      return;
    }
    final query = q.toLowerCase();
    setState(() {
      _filtered = widget.category.verbs
          .where((v) =>
              v.v1.toLowerCase().contains(query) ||
              v.v2.toLowerCase().contains(query) ||
              v.v3.toLowerCase().contains(query) ||
              v.v4.toLowerCase().contains(query) ||
              v.v5.toLowerCase().contains(query) ||
              v.bangla.contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cat = widget.category;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(cat.icon, color: cat.color, size: 26),
            const SizedBox(width: 8),
            Text(cat.title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search verb...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered!.length,
              itemBuilder: (_, i) => _buildVerbCard(_filtered![i], isDark, theme, cat.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerbCard(VerbForm v, bool isDark, ThemeData theme, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 22,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(v.bangla,
                        style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(v.meaning,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FormChip(label: 'V1', value: v.v1, color: AppColors.primary),
                  const SizedBox(width: 4),
                  _FormChip(label: 'V2', value: v.v2, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  _FormChip(label: 'V3', value: v.v3, color: AppColors.warning),
                  const SizedBox(width: 4),
                  _FormChip(label: 'V4', value: v.v4, color: AppColors.info),
                  const SizedBox(width: 4),
                  _FormChip(label: 'V5', value: v.v5, color: AppColors.pinkGradient[0]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FormChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
