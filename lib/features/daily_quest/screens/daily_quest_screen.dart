import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quest_provider.dart';
import '../models/daily_quest_model.dart';
import '../models/daily_quest_task_model.dart';

/// Full Daily Quest screen showing all tasks, progress, and bonus.
/// Duolingo‑style: top → streak + progress, center → task list, bottom → bonus.
class DailyQuestScreen extends ConsumerWidget {
  const DailyQuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questState = ref.watch(dailyQuestProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quest = questState.quest;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌟 Daily Quest',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (quest != null && questState.justCompleted)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.celebration, color: Colors.yellowAccent, size: 28),
            ),
        ],
      ),
      body: quest == null
          ? const Center(child: CircularProgressIndicator())
          : _buildQuestContent(context, ref, theme, isDark, quest, questState),
    );
  }

  Widget _buildQuestContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isDark,
    DailyQuest quest,
    DailyQuestState questState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Streak + Date ──
          _buildHeader(quest, theme),
          const SizedBox(height: 20),

          // ── Progress bar + label ──
          _buildProgressSection(quest, theme),
          const SizedBox(height: 24),

          // ── Task list ──
          Text(
            'Today\'s Tasks',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...quest.tasks.map((task) => _buildTaskTile(context, ref, task, theme, isDark)),

          const SizedBox(height: 24),

          // ── Completion Bonus ──
          if (quest.isCompleted) ...[
            _buildCompletionBanner(quest, theme, isDark),
          ] else ...[
            _buildBonusPreview(quest, theme, isDark),
          ],

          const SizedBox(height: 32),

          // ── Tip ──
          if (!quest.isCompleted)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete all tasks to earn the bonus reward! '
                      'New quest every day — never miss a day!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
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

  Widget _buildHeader(DailyQuest quest, ThemeData theme) {
    final now = DateTime.now();
    final dateStr =
        '${now.day} ${_monthName(now.month)}, ${now.year}';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.calendar_today_rounded,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              '${quest.completedTasks} of ${quest.totalTasks} tasks completed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (quest.isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Done!',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgressSection(DailyQuest quest, ThemeData theme) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: quest.progress.isNaN ? 0 : quest.progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: quest.isCompleted ? Colors.green : AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              quest.progressLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            Text(
              quest.isCompleted
                  ? '🎉 100% Complete!'
                  : '${(quest.progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: quest.isCompleted ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    DailyQuestTaskModel task,
    ThemeData theme,
    bool isDark,
  ) {
    final iconMap = <String, IconData>{
      'grammar': Icons.text_fields_rounded,
      'vocabulary': Icons.book_rounded,
      'speaking': Icons.record_voice_over_rounded,
      'listening': Icons.headphones_rounded,
      'translation': Icons.translate_rounded,
      'mixed': Icons.shuffle_rounded,
      'conversation': Icons.chat_rounded,
    };

    final colorMap = <String, Color>{
      'grammar': Colors.indigo,
      'vocabulary': Colors.teal,
      'speaking': Colors.deepOrange,
      'listening': Colors.purple,
      'translation': Colors.blue,
      'mixed': Colors.amber.shade700,
      'conversation': Colors.pink,
    };

    final icon = iconMap[task.taskType] ?? Icons.task_alt;
    final color = colorMap[task.taskType] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isCompleted
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: task.isCompleted
            ? null
            : () => _navigateToTask(context, ref, task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              // Title + desc
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration:
                            task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // XP / Coins badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${task.xpReward} XP',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${task.coinReward} 🪙',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Checkmark
              Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isCompleted ? Colors.green : Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionBanner(
      DailyQuest quest, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Quest Complete! 🎉',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You earned ${quest.earnedXP} XP & ${quest.earnedCoins} coins today!',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _rewardBadge('${quest.earnedXP} XP', AppColors.primary),
              const SizedBox(width: 12),
              _rewardBadge('${quest.earnedCoins} 🪙', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildBonusPreview(DailyQuest quest, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.amber, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completion Bonus',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete all tasks to earn '
                  '+${quest.completionBonusXP} XP & +${quest.completionBonusCoins} coins!',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTask(
      BuildContext context, WidgetRef ref, DailyQuestTaskModel task) {
    // Map each task type to its screen route
    // All routes use Navigator.push with MaterialPageRoute since
    // this project doesn't use named routes
    switch (task.taskType) {
      case 'grammar':
        Navigator.pushNamed(context, '/game/mode');
        break;
      case 'vocabulary':
        Navigator.pushNamed(context, '/vocabulary');
        break;
      case 'speaking':
        Navigator.pushNamed(context, '/practice');
        break;
      case 'listening':
        Navigator.pushNamed(context, '/practice',
            arguments: {'mode': 'listening'});
        break;
      case 'translation':
        Navigator.pushNamed(context, '/translator');
        break;
      case 'mixed':
        Navigator.pushNamed(context, '/game/mode',
            arguments: {'mode': 'mixed_challenge'});
        break;
      case 'conversation':
        Navigator.pushNamed(context, '/ai_teacher');
        break;
      default:
        // Fallback: open game home
        Navigator.pushNamed(context, '/game');
    }

    // Note: The task will be marked complete when the user returns from
    // the game screen and the game provider detects completion.
    // For now we rely on the game provider callback mechanism.
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }
}
