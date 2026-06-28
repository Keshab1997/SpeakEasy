import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/feedback_model.dart';
import '../../../services/ai_service.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Feedback',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Resolved'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedbackList('pending'),
          _buildFeedbackList('resolved'),
          _buildFeedbackList(null),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(String? statusFilter) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: statusFilter != null
          ? _firestore
              .collection('feedback')
              .where('status', isEqualTo: statusFilter)
              .orderBy('createdAt', descending: true)
              .snapshots()
          : _firestore
              .collection('feedback')
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
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  statusFilter == 'pending'
                      ? 'No pending feedback'
                      : statusFilter == 'resolved'
                          ? 'No resolved feedback'
                          : 'No feedback yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusFilter == 'pending'
                      ? 'New feedback from users will appear here'
                      : statusFilter == 'resolved'
                          ? 'Resolved feedback will appear here'
                          : 'User feedback will appear here',
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

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final feedback =
                FeedbackModel.fromMap(docs[index].data(), docs[index].id);
            return _FeedbackCard(
              feedback: feedback,
              onResolved: () => _markAsResolved(feedback.id),
              onReply: (reply) => _submitReply(feedback.id, reply),
            );
          },
        );
      },
    );
  }

  Future<void> _markAsResolved(String docId) async {
    try {
      await _firestore.collection('feedback').doc(docId).update({
        'status': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback marked as resolved'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitReply(String docId, String reply) async {
    try {
      await _firestore.collection('feedback').doc(docId).update({
        'adminReply': reply,
        'status': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent and feedback marked as resolved'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reply: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _FeedbackCard extends StatefulWidget {
  final FeedbackModel feedback;
  final Future<void> Function() onResolved;
  final Future<void> Function(String reply) onReply;

  const _FeedbackCard({
    required this.feedback,
    required this.onResolved,
    required this.onReply,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _expanded = false;
  final _replyController = TextEditingController();
  bool _isSending = false;
  bool _isGeneratingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedback = widget.feedback;

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
          // Main card content (always visible)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info + status row
                  Row(
                    children: [
                      // User avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _categoryColor().withOpacity(0.15),
                        child: Icon(
                          _categoryIcon(),
                          color: _categoryColor(),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // User name and email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feedback.userName.isNotEmpty
                                  ? feedback.userName
                                  : 'Anonymous',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (feedback.userEmail.isNotEmpty)
                              Text(
                                feedback.userEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
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

                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _categoryColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcon(),
                          size: 14,
                          color: _categoryColor(),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          feedback.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

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

          // Expanded section (reply area)
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show existing reply if any
                  if (feedback.adminReply != null &&
                      feedback.adminReply!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.reply_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Your Reply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feedback.adminReply!,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Reply input (only if not already replied or still editable)
                  if (feedback.status == 'pending') ...[
                    Row(
                      children: [
                        Text(
                          'Write a Reply',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        _isGeneratingReply
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                              )
                            : GestureDetector(
                                onTap: _generateAiReply,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'AI Reply',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.backgroundDark : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: TextField(
                        controller: _replyController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Type your reply here...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.black26,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showResolveConfirmation(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text(
                              'Mark Resolved',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendReply,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.6),
                            ),
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _isSending ? 'Sending...' : 'Send Reply',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reply message'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await widget.onReply(reply);
      if (mounted) {
        setState(() {
          _isSending = false;
          _replyController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _generateAiReply() async {
    final feedback = widget.feedback;
    if (_isGeneratingReply) return;

    setState(() => _isGeneratingReply = true);

    try {
      final response = await AIService().sendMessageWithSystem(
        'User feedback category: ${feedback.category}\nUser message: ${feedback.message}',
        maxTokens: 250,
        systemPrompt: 'You are a professional customer support agent for a "Spoken English Learning App". '
            'Write a kind, empathetic, and encouraging reply to a user\'s feedback. '
            'Keep it concise (2-4 sentences). Use friendly English with occasional Bangla/Banglish words. '
            'Always thank the user for their feedback.\n\n'
            'Guidelines by category:\n'
            '- Bug Report: Apologize sincerely and mention the team will look into it.\n'
            '- Feature Request: Appreciate the suggestion and say it will be considered.\n'
            '- Complaint: Be very apologetic and reassuring.\n'
            '- Suggestion: Acknowledge positively and thank them.\n'
            '- Other: Respond warmly and acknowledge their input.\n\n'
            'Return ONLY the reply text. No quotes, no prefixes, no labels.',
      );

      if (mounted && response.isNotEmpty) {
        // Clean up any markdown or quotes from the response
        String cleanReply = response.trim();
        cleanReply = cleanReply.replaceAll(RegExp("^[\"'*]+"), '');
        cleanReply = cleanReply.replaceAll(RegExp("[\"'*]+\$"), '');
        cleanReply = cleanReply.trim();
        _replyController.text = cleanReply;
      }
    } catch (e) {
      // AI unavailable - use a fallback reply based on category
      if (mounted) {
        final fallback = _buildFallbackAiReply(feedback.category, feedback.userName);
        _replyController.text = fallback;
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReply = false);
      }
    }
  }

  String _buildFallbackAiReply(String category, String userName) {
    final greeting = userName.isNotEmpty ? 'Dear $userName' : 'Dear User';
    switch (category) {
      case 'Bug Report':
        return '$greeting,\n\nThank you for reporting this issue. We sincerely apologize for the inconvenience. Our team will look into this and fix it as soon as possible. Thank you for your patience! 🙏';
      case 'Feature Request':
        return '$greeting,\n\nThank you for your wonderful suggestion! We really appreciate your input and will definitely consider adding this feature in future updates. Keep learning! 🚀';
      case 'Complaint':
        return '$greeting,\n\nWe are truly sorry for your experience. Your feedback is very important to us, and we will work hard to improve. Please give us another chance to serve you better. 🙏';
      case 'Suggestion':
        return '$greeting,\n\nThank you for your thoughtful suggestion! We always love hearing from our learners. Your idea has been noted and will be reviewed by our team. Keep practicing! 📚';
      default:
        return '$greeting,\n\nThank you for reaching out to us! We really value your feedback as it helps us improve the app for everyone. Keep learning English with us! 🎉';
    }
  }

  Future<void> _showResolveConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: const Text(
          'Mark this feedback as resolved without sending a reply?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.onResolved();
    }
  }
}
