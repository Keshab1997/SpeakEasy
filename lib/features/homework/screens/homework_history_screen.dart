import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';


class HomeworkHistoryScreen extends ConsumerStatefulWidget {
  const HomeworkHistoryScreen({super.key});

  @override
  ConsumerState<HomeworkHistoryScreen> createState() => _HomeworkHistoryScreenState();
}

class _HomeworkHistoryScreenState extends ConsumerState<HomeworkHistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _sessions = HiveService.getHomeworkHistory());
  }

  Future<void> _deleteSession(int index) async {
    await HiveService.deleteHomeworkSession(index);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This cannot be undone.'),
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
      await HiveService.clearAllHomeworkSessions();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Homework History', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No homework history yet',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text('Complete a homework and save it to see it here.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400])),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey[50],
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                  ),
                  child: Row(
                    children: [
                      Text('${_sessions.length} sessions',
                        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) => _buildSessionCard(theme, isDark, i),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSessionCard(ThemeData theme, bool isDark, int index) {
    final s = _sessions[index];
    final topic = s['topic'] as String? ?? 'Untitled';
    final date = s['date'] as String? ?? '';
    final score = s['score'] as int? ?? 0;
    final total = s['total'] as int? ?? 10;
    final percentage = total > 0 ? score / total : 0.0;
    final questions = s['questions'] as List<dynamic>? ?? [];

    return Dismissible(
      key: Key('homework_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteSession(index),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _HomeworkDetailScreen(session: s, index: index),
          ),
        ).then((_) => _loadHistory()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: percentage >= 0.7
                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                      : percentage >= 0.4
                          ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                          : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('${(percentage * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.quiz_rounded, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('$score/$total',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_formatDate(date),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: percentage >= 0.7 ? Colors.green : percentage >= 0.4 ? Colors.orange : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeworkDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  final int index;

  const _HomeworkDetailScreen({
    required this.session,
    required this.index,
  });

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topic = session['topic'] as String? ?? 'Untitled';
    final date = session['date'] as String? ?? '';
    final score = session['score'] as int? ?? 0;
    final total = session['total'] as int? ?? 10;
    final percentage = total > 0 ? score / total : 0.0;
    final questions = session['questions'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(topic, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this session?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await HiveService.deleteHomeworkSession(index);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: percentage >= 0.7
                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                      : percentage >= 0.4
                          ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                          : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(_formatDate(date),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    const SizedBox(height: 12),
                    Text('$score / $total',
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${(percentage * 100).toInt()}% Accuracy',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Detailed Review',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            ...List.generate(questions.length, (i) {
              final q = questions[i] as Map<String, dynamic>;
              return _buildResultCard(theme, isDark, q, i);
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, bool isDark, Map<String, dynamic> q, int index) {
    final isCorrect = q['isCorrect'] as bool? ?? false;
    final bangla = q['bangla'] as String? ?? '';
    final userTranslation = q['userTranslation'] as String? ?? '';
    final correctTranslation = q['correctTranslation'] as String? ?? '';
    final feedback = q['feedback'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCorrect ? 'CORRECT' : 'WRONG',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                Text('#${index + 1}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('বাংলা:', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(bangla,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Answer:',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          userTranslation.isNotEmpty ? userTranslation : '(empty)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isCorrect ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Correct:',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          correctTranslation,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (feedback.isNotEmpty && !isCorrect) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feedback,
                        style: TextStyle(
                          color: isDark ? Colors.grey[200] : Colors.black87,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
