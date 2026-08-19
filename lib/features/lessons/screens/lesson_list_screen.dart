import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final beginnerLessons = [
      {'title': 'English Alphabet & Phonics', 'duration': '10 mins', 'status': 'Completed', 'progress': 1.0},
      {'title': 'Basic Greeting Phrases', 'duration': '15 mins', 'status': 'Completed', 'progress': 1.0},
      {'title': 'Self Introduction Guide', 'duration': '12 mins', 'status': 'In Progress', 'progress': 0.5},
      {'title': 'Numbers & Telling Time', 'duration': '8 mins', 'status': 'Locked', 'progress': 0.0},
    ];

    final intermediateLessons = [
      {'title': 'Understanding Present Tense', 'duration': '20 mins', 'status': 'Locked', 'progress': 0.0},
      {'title': 'Common Prepositions', 'duration': '18 mins', 'status': 'Locked', 'progress': 0.0},
      {'title': 'Asking for Directions', 'duration': '15 mins', 'status': 'Locked', 'progress': 0.0},
      {'title': 'Shopping & Ordering Food', 'duration': '22 mins', 'status': 'Locked', 'progress': 0.0},
    ];

    final advancedLessons = [
      {'title': 'Interview English & Resumes', 'duration': '25 mins', 'status': 'Locked', 'progress': 0.0},
      {'title': 'Business Presentations', 'duration': '30 mins', 'status': 'Locked', 'progress': 0.0},
      {'title': 'Idiomatic Phrases in Daily Life', 'duration': '20 mins', 'status': 'Locked', 'progress': 0.0},
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'English Courses',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Beginner'),
              Tab(text: 'Intermediate'),
              Tab(text: 'Advanced'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLessonsList(context, beginnerLessons, isDark),
            _buildLessonsList(context, intermediateLessons, isDark),
            _buildLessonsList(context, advancedLessons, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsList(BuildContext context, List<Map<String, dynamic>> lessons, bool isDark) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final isCompleted = lesson['status'] == 'Completed';
        final isInProgress = lesson['status'] == 'In Progress';
        final isLocked = lesson['status'] == 'Locked';
        final progress = lesson['progress'] as double;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isInProgress
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isInProgress ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Lesson Status Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : (isInProgress
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : (isDark ? Colors.grey[850] : Colors.grey[100])),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : (isInProgress
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_outline_rounded),
                    color: isCompleted
                        ? AppColors.secondary
                        : (isInProgress ? AppColors.primary : Colors.grey),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Lesson Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson['title'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLocked ? (isDark ? Colors.white38 : Colors.black38) : null,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isLocked ? Colors.grey[600] : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lesson['duration'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isLocked ? Colors.grey[600] : Colors.grey,
                            ),
                          ),
                          if (isInProgress) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'In Progress',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isInProgress) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isLocked ? (isDark ? Colors.white10 : Colors.black12) : Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
