import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';

class SentenceAnalysisHistoryScreen extends StatefulWidget {
  const SentenceAnalysisHistoryScreen({super.key});

  @override
  State<SentenceAnalysisHistoryScreen> createState() => _SentenceAnalysisHistoryScreenState();
}

class _SentenceAnalysisHistoryScreenState extends State<SentenceAnalysisHistoryScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _items = HiveService.getSentenceAnalysisHistory());
  }

  Future<void> _deleteItem(int index) async {
    await HiveService.deleteSentenceAnalysis(index);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Saved Analyses?'),
        content: const Text('All saved sentence analyses will be deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await HiveService.clearSentenceAnalysisHistory();
      _loadHistory();
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _shortTense(String tense) {
    final parts = tense.split('—');
    return parts.first.trim().isEmpty ? 'Sentence Analysis' : parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bookmark_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Saved Analyses', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 72, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No saved analyses yet',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[500], fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyze a sentence and tap Save to keep it in this list.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, index) => _buildHistoryCard(theme, isDark, index),
            ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme, bool isDark, int index) {
    final item = _items[index];
    final sentence = item['banglaSentence']?.toString() ?? 'Untitled sentence';
    final english = item['englishTranslation']?.toString() ?? '';
    final tense = item['tense']?.toString() ?? '';
    final date = item['date']?.toString() ?? '';

    return Dismissible(
      key: Key('sentence_analysis_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteItem(index),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _SentenceAnalysisDetailScreen(item: item, formattedDate: _formatDate(date))),
        ).then((_) => _loadHistory()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    if (english.isNotEmpty)
                      Text(
                        english,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _shortTense(tense),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _formatDate(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteItem(index),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceAnalysisDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  final String formattedDate;

  const _SentenceAnalysisDetailScreen({required this.item, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final task = item['practiceTask'] is Map ? Map<String, dynamic>.from(item['practiceTask'] as Map) : null;
    final review = item['answerReview'] is Map ? Map<String, dynamic>.from(item['answerReview'] as Map) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Details', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('SAVED SENTENCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Text(
                    item['banglaSentence']?.toString() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['englishTranslation']?.toString() ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),
                  Text(formattedDate, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _detailCard(theme, isDark, 'Tense (কাল)', item['tense']?.toString() ?? '', Icons.schedule_rounded, const Color(0xFF06B6D4)),
            _detailCard(theme, isDark, 'Subject (কর্তা)', item['subject']?.toString() ?? '', Icons.person_rounded, const Color(0xFF10B981)),
            _detailCard(theme, isDark, 'Object (কর্ম)', (item['object']?.toString().isNotEmpty ?? false) ? item['object'].toString() : 'No object (অকর্মক বাক্য)', Icons.ads_click_rounded, const Color(0xFFF59E0B)),
            _detailCard(theme, isDark, 'Word Breakdown', item['wordBreakdown']?.toString() ?? '', Icons.abc_rounded, AppColors.primary),
            _detailCard(theme, isDark, 'Explanation', item['explanation']?.toString() ?? '', Icons.lightbulb_rounded, const Color(0xFF8B5CF6)),
            if (task != null) ...[
              const SizedBox(height: 8),
              _detailCard(theme, isDark, 'Practice Task', task['instruction']?.toString() ?? '', Icons.quiz_rounded, const Color(0xFFF59E0B)),
              _detailCard(theme, isDark, 'Correct Answer', task['correctAnswer']?.toString() ?? '', Icons.check_circle_rounded, AppColors.success),
            ],
            if (review != null) ...[
              const SizedBox(height: 8),
              _detailCard(theme, isDark, 'Your Answer', item['userAnswer']?.toString() ?? '', Icons.edit_rounded, AppColors.primary),
              _detailCard(theme, isDark, 'Feedback', review['feedback']?.toString() ?? '', Icons.rate_review_rounded, (review['isCorrect'] == true) ? AppColors.success : Colors.orange),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailCard(ThemeData theme, bool isDark, String label, String value, IconData icon, Color color) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
