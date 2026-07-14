import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../repository/admin_repository.dart';
import 'admin_analytics_screen.dart';
import 'admin_config_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_api_keys_screen.dart';
import 'admin_error_logs_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_user_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminRepository();
  final _ideaController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _linkController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sending = false;
  bool _generating = false;
  @override
  void dispose() {
    _ideaController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _linkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            tooltip: 'Feedback',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminFeedbackScreen(),
              ),
            ),
            icon: const Icon(Icons.feedback_rounded),
          ),
          IconButton(
            tooltip: 'Analytics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAnalyticsScreen(),
              ),
            ),
            icon: const Icon(Icons.analytics_rounded),
          ),
          IconButton(
            tooltip: 'Sent Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminNotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'App Config',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminConfigScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_applications_rounded),
          ),
          IconButton(
            tooltip: 'API Keys',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminApiKeysScreen()),
            ),
            icon: const Icon(Icons.vpn_key_rounded),
          ),
          IconButton(
            tooltip: 'Error Logs',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminErrorLogsScreen()),
            ),
            icon: const Icon(Icons.report_problem_rounded),
          ),
          IconButton(
            tooltip: 'Info',
            onPressed: _showInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repository.usersStream(limit: 200),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load students: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const _AdminSkeleton();
          }

          final users = snapshot.data!.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
          final students = users.where((user) => user.role != 'admin').toList();
          final admins = users.where((user) => user.role == 'admin').toList();

          final filteredUsers = _searchQuery.isEmpty
              ? users
              : users.where((u) {
                  final q = _searchQuery.toLowerCase();
                  return u.name.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q);
                }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsRow(users.length, students.length, admins.length),
              const SizedBox(height: 16),
              _buildNotificationComposer(isDark, students.length),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Users (${filteredUsers.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...filteredUsers.map((user) => _buildUserTile(user, isDark)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(int total, int students, int admins) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total', total, Icons.groups_rounded, AppColors.primaryGradient)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Students', students, Icons.school_rounded, AppColors.secondaryGradient)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Admins', admins, Icons.admin_panel_settings_rounded, AppColors.purpleGradient)),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNotificationComposer(bool isDark, int studentCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Send Notification', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This saves an admin announcement for all students. Cloud Function/FCM can deliver it as push notification.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ideaController,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'AI idea / topic',
              hintText: 'e.g. kal vocabulary test ache, sobai practice koro',
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generating ? null : _generateNotificationWithAi,
              icon: _generating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(_generating ? 'AI writing...' : 'Write with AI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Message',
              prefixIcon: const Icon(Icons.message_rounded),
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: 'Link (optional)',
              hintText: 'e.g. https://play.google.com/store/apps/details?id=...',
              prefixIcon: const Icon(Icons.link_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : () => _sendAnnouncement(studentCount),
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Sending...' : 'Send to $studentCount students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user, bool isDark) {
    final roleColor = user.role == 'admin' ? AppColors.purpleGradient.first : AppColors.secondary;

    return Card(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.12),
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          child: user.photoUrl.isEmpty
              ? Text(_initials(user.name), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold))
              : null,
        ),
        title: Text(user.name.isEmpty ? 'Unnamed User' : user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${user.email}\nJoined: ${_formatDate(user.joinedAt)} | Level: ${user.currentLevel}'),
        isThreeLine: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(user: user),
          ),
        ),
        trailing: PopupMenuButton<String>(
          initialValue: user.role,
          onSelected: (role) => _changeRole(user, role),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'student', child: Text('Make Student')),
            PopupMenuItem(value: 'admin', child: Text('Make Admin')),
          ],
          child: Chip(
            label: Text(user.role.toUpperCase()),
            labelStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            backgroundColor: roleColor,
          ),
        ),
      ),
    );
  }

  Future<void> _sendAnnouncement(int studentCount) async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnack('Title and message are required.', isError: true);
      return;
    }

    final link = _linkController.text.trim();
    final actionUrl = link.isNotEmpty ? link : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send to $studentCount students?',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _previewField('Title', title),
            const SizedBox(height: 6),
            _previewField('Message', body),
            if (actionUrl != null) ...[
              const SizedBox(height: 6),
              _previewField('Link', actionUrl),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Send Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);

    // Save to Firestore
    var firestoreDocId = '';
    try {
      firestoreDocId = await _repository.sendNotification(
        title: title,
        body: body,
        link: actionUrl,
        targetRole: 'student',
        targetCount: studentCount,
      );
    } catch (e) {
      debugPrint('Firestore save failed (non-critical): $e');
    }

    // Send push via OneSignal API
    final pushResult = await _repository.sendPushNotification(
      title: title,
      body: body,
      link: actionUrl,
      firestoreDocId: firestoreDocId.isNotEmpty ? firestoreDocId : null,
    );

    _titleController.clear();
    _bodyController.clear();
    _linkController.clear();

    if (pushResult) {
      _showSnack('✅ Push notification sent to $studentCount students!');
    } else {
      _showSnack(
        '⚠️ Notification saved but push delivery failed. '
        'Send from OneSignal Dashboard instead.',
        isError: true,
      );
    }

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _generateNotificationWithAi() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      _showSnack('AI ke idea/topic dao first.', isError: true);
      return;
    }

    setState(() => _generating = true);
    try {
      final response = await _repository.generateNotificationContent(idea);
      final generated = _parseAiNotification(response);
      _titleController.text = generated.$1;
      _bodyController.text = generated.$2;
      _showSnack('AI notification ready. Review kore send koro.');
    } catch (e) {
      final fallback = _buildFallbackAiMessage(idea);
      _titleController.text = fallback.$1;
      _bodyController.text = fallback.$2;
      _showSnack('AI unavailable, ami ekta draft ready kore dilam.', isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  (String, String) _parseAiNotification(String response) {
    final lines = response.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);
    var title = '';
    var body = '';

    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.startsWith('TITLE:')) {
        title = line.substring(line.indexOf(':') + 1).trim();
      } else if (upper.startsWith('BODY:')) {
        body = line.substring(line.indexOf(':') + 1).trim();
      } else if (body.isNotEmpty) {
        body = '$body ${line.trim()}';
      }
    }

    if (title.isEmpty || body.isEmpty) {
      final clean = response.replaceAll(RegExp(r'[*#`>-]'), '').trim();
      final parts = clean.split(RegExp(r'\n+'));
      title = parts.isNotEmpty ? parts.first.trim() : '📢 New Update!';
      body = parts.length > 1 ? parts.skip(1).join(' ').trim() : clean;
    }

    if (title.length > 55) title = '${title.substring(0, 52)}...';
    if (body.length > 180) body = '${body.substring(0, 177)}...';
    return (title.isEmpty ? '📢 New Update!' : title, body.isEmpty ? 'Open the app and keep learning English today! 🚀' : body);
  }

  (String, String) _buildFallbackAiMessage(String idea) {
    final cleanIdea = idea.length > 120 ? '${idea.substring(0, 117)}...' : idea;
    return (
      '📢 Important Update!',
      '$cleanIdea ✨ Keep practicing English today. Cholo, aajker learning complete kori! 🚀',
    );
  }

  Future<void> _changeRole(UserModel user, String role) async {
    if (user.role == role) return;

    try {
      await _repository.updateUserRole(user.id, role);
      _showSnack('${user.name.isEmpty ? user.email : user.name} is now $role.');
    } catch (e) {
      _showSnack('Failed to update role: $e', isError: true);
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Panel Setup'),
        content: const Text(
          'To make yourself admin, set your Firestore users/{uid}.role field to "admin" once. '
          'Push delivery needs a backend Cloud Function that listens to admin_notifications and sends FCM.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _previewField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _AdminSkeleton extends StatelessWidget {
  const _AdminSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _Skel(height: 90)),
            const SizedBox(width: 10),
            Expanded(child: _Skel(height: 90)),
            const SizedBox(width: 10),
            Expanded(child: _Skel(height: 90)),
          ],
        ),
        const SizedBox(height: 16),
        _Skel(height: 200),
        const SizedBox(height: 20),
        _Skel(height: 14, width: 150),
        const SizedBox(height: 12),
        ...List.generate(5, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Skel(height: 72),
        )),
      ],
    );
  }
}

class _Skel extends StatelessWidget {
  final double height;
  final double width;
  const _Skel({this.height = 16, this.width = double.infinity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
