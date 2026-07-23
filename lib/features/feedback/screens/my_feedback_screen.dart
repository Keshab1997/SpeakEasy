import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../models/feedback_model.dart';
import '../../../providers/auth_provider.dart';

class MyFeedbackScreen extends ConsumerStatefulWidget {
  const MyFeedbackScreen({super.key});

  @override
  ConsumerState<MyFeedbackScreen> createState() => _MyFeedbackScreenState();
}

class _MyFeedbackScreenState extends ConsumerState<MyFeedbackScreen> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Feedback',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: user == null
          ? _buildSignedOutState(isDark)
          : _buildFeedbackList(user.id, isDark),
    );
  }

  Widget _buildSignedOutState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to view your feedback',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your submitted feedback and admin replies will appear here',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(String userId, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Failed to load feedback:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (_, __) => const SkeletonListTile(),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return RefreshIndicator(
          onRefresh: () => _firestore
              .collection('feedback')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get()
              .then((_) {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final feedback =
                  FeedbackModel.fromMap(docs[index].data(), docs[index].id);
              return _MyFeedbackCard(
                feedback: feedback,
                isDark: isDark,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No feedback submitted yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you submit feedback, it will appear here along\nwith any replies from the admin.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MyFeedbackCard extends StatefulWidget {
  final FeedbackModel feedback;
  final bool isDark;

  const _MyFeedbackCard({
    required this.feedback,
    required this.isDark,
  });

  @override
  State<_MyFeedbackCard> createState() => _MyFeedbackCardState();
}

class _MyFeedbackCardState extends State<_MyFeedbackCard> {
  bool _expanded = false;

  Color _categoryColor() {
    switch (widget.feedback.category) {
      case 'Bug Report':
        return AppColors.error;
      case 'Feature Request':
        return AppColors.info;
      case 'Complaint':
        return AppColors.warning;
      case 'Suggestion':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon() {
    switch (widget.feedback.category) {
      case 'Bug Report':
        return Icons.bug_report_rounded;
      case 'Feature Request':
        return Icons.lightbulb_rounded;
      case 'Complaint':
        return Icons.report_problem_rounded;
      case 'Suggestion':
        return Icons.tips_and_updates_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Main card content
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Category icon + Status badge
                  Row(
                    children: [
                      // Category icon in circle
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _categoryColor().withOpacity(0.15),
                        child: Icon(
                          _categoryIcon(),
                          color: _categoryColor(),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Category name
                      Text(
                        feedback.category,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _categoryColor(),
                        ),
                      ),
                      const Spacer(),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: feedback.status == 'resolved'
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          feedback.status == 'resolved'
                              ? 'Resolved'
                              : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: feedback.status == 'resolved'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    feedback.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Timestamp + expand indicator
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatDate(feedback.createdAt)} at ${_formatTime(feedback.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white30 : Colors.black38,
                        ),
                      ),
                      const Spacer(),

                      // Show reply indicator if admin replied
                      if (feedback.adminReply != null &&
                          feedback.adminReply!.isNotEmpty) ...[
                        Icon(
                          Icons.reply_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Replied',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded section (admin reply)
          if (_expanded && feedback.adminReply != null &&
              feedback.adminReply!.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Admin Reply',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          feedback.adminReply!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        if (feedback.updatedAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Replied on ${_formatDate(feedback.updatedAt!)} at ${_formatTime(feedback.updatedAt!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // If no reply yet and expanded, show a waiting state
          if (_expanded && (feedback.adminReply == null ||
              feedback.adminReply!.isEmpty)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.15),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Awaiting Reply',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The admin will review and respond to your feedback soon.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
