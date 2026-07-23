import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../models/guide_model.dart';
import '../services/guide_service.dart';

/// Screen that displays Student Guide & Study Routine with a TabBar.
class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  GuideData? _studentGuide;
  GuideData? _studyRoutine;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGuides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGuides() async {
    try {
      final results = await Future.wait([
        GuideService.loadStudentGuide(),
        GuideService.loadStudyRoutine(),
      ]);
      if (mounted) {
        setState(() {
          _studentGuide = results[0];
          _studyRoutine = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'গাইড লোড করা যায়নি: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guides & Resources',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Student Guide',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Study Routine',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: Column(
          children: [
            SkeletonParagraph(lines: 4),
            SkeletonParagraph(lines: 3),
            SkeletonParagraph(lines: 4),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadGuides();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('পুনরায় চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _GuideContentView(guide: _studentGuide!),
        _GuideContentView(guide: _studyRoutine!),
      ],
    );
  }
}

/// Renders the full content of a guide with expandable sections.
class _GuideContentView extends StatelessWidget {
  final GuideData guide;

  const _GuideContentView({required this.guide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          _buildHeaderCard(theme, isDark),
          const SizedBox(height: 20),

          // Sections
          for (int i = 0; i < guide.sections.length; i++) ...[
            _buildSectionCard(theme, isDark, guide.sections[i], i),
            if (i < guide.sections.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(guide.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            guide.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            guide.subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      ThemeData theme, bool isDark, GuideSection section, int index) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          section.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        children: [
          // Main content text
          if (section.content != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                section.content!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),

          // Bullet points
          if (section.bullets != null) ...[
            for (final bullet in section.bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Subsections
          if (section.subsections != null)
            for (final sub in section.subsections!)
              _buildSubSection(theme, isDark, sub),

          // Table
          if (section.table != null)
            _buildTable(theme, isDark, section.table!),

          // Note
          if (section.note != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.note!,
                      style: TextStyle(
                        color: AppColors.accent.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Footer — prominent motivational message
          if (section.footer != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.accent.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.accent, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    section.footer!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubSection(
      ThemeData theme, bool isDark, GuideSubSection sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          if (sub.content != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                sub.content!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          if (sub.bullets != null)
            for (final bullet in sub.bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('▸ ',
                        style: TextStyle(
                            color: AppColors.primary.withOpacity(0.6),
                            fontSize: 14)),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTable(ThemeData theme, bool isDark, GuideTable table) {
    if (table.headers.isEmpty || table.rows.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            AppColors.primary.withOpacity(0.08),
          ),
          dataRowColor: MaterialStateProperty.all(Colors.transparent),
          columnSpacing: 16,
          dataRowMinHeight: 44,
          dataRowMaxHeight: double.infinity,
          columns: table.headers
              .map((h) => DataColumn(
                    label: Text(h,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primary)),
                  ))
              .toList(),
          rows: table.rows.map((row) {
            return DataRow(
              cells: row
                  .map((cell) => DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            cell,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}
