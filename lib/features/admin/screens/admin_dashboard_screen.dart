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

/// Redesigned Admin Panel:
///  • No realtime 200-doc listener on entry — uses count() aggregation + paginated fetch
///  • Clean sections: Stats → Quick Actions → Notification composer → Users (paginated, search)
///  • Manual refresh only, not continuous stream (saves Firestore reads)
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

  // ── Stats (count aggregation, not doc fetch) ──
  int _total = 0, _students = 0, _admins = 0;
  bool _statsLoading = true;

  // ── Users (paginated, not stream) ──
  List<UserModel> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _usersLoading = true;
  bool _usersLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  static const int _pageSize = 30;

  bool _sending = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUsers(reset: true);
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _linkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final counts = await _repository.getUserCounts();
      if (!mounted) return;
      setState(() {
        _total = counts['total'] ?? 0;
        _admins = counts['admins'] ?? 0;
        _students = counts['students'] ?? 0;
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _usersLoading = true;
        _users = [];
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      setState(() => _usersLoadingMore = true);
    }
    try {
      final snap = await _repository.loadMoreUsers(
        lastDoc: reset ? null : _lastDoc,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final fetched = snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
      setState(() {
        if (reset) {
          _users = fetched;
        } else {
          _users.addAll(fetched);
        }
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
        _usersLoading = false;
        _usersLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() { _usersLoading = false; _usersLoadingMore = false; });
    }
  }

  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Refresh all',
            onPressed: () { _loadStats(); _loadUsers(reset: true); },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(tooltip: 'Info', onPressed: _showInfo, icon: const Icon(Icons.info_outline_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadStats(); await _loadUsers(reset: true); },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stats row — count() only, no doc fetch ──
            _statsLoading ? const _StatsSkeleton() : _buildStatsRow(),
            const SizedBox(height: 8),
            Text('Counts via Firestore count() — 2 reads only', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(height: 18),

            // ── Quick actions grid — replaces 6 icons in AppBar ──
            _buildQuickActionsGrid(isDark),
            const SizedBox(height: 20),

            // ── Notification composer ──
            _buildNotificationComposer(isDark),
            const SizedBox(height: 20),

            // ── Users section ──
            _buildUsersSection(isDark),
          ],
        ),
      ),
    );
  }

  // ── Stats ──
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Users', _total, Icons.groups_rounded, AppColors.primaryGradient)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Students', _students, Icons.school_rounded, AppColors.secondaryGradient)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard('Admins', _admins, Icons.admin_panel_settings_rounded, AppColors.purpleGradient)),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 10),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Quick actions ──
  Widget _buildQuickActionsGrid(bool isDark) {
    final actions = [
      _ActionItem('Analytics', Icons.analytics_rounded, AppColors.primary, () => _push(const AdminAnalyticsScreen())),
      _ActionItem('App Config', Icons.settings_applications_rounded, AppColors.secondary, () => _push(const AdminConfigScreen())),
      _ActionItem('API Keys', Icons.vpn_key_rounded, Colors.orange, () => _push(const AdminApiKeysScreen())),
      _ActionItem('Feedback', Icons.feedback_rounded, Colors.teal, () => _push(const AdminFeedbackScreen())),
      _ActionItem('Sent History', Icons.history_rounded, Colors.indigo, () => _push(const AdminNotificationsScreen())),
      _ActionItem('Error Logs', Icons.report_problem_rounded, AppColors.error, () => _push(const AdminErrorLogsScreen())),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1),
        itemCount: actions.length,
        itemBuilder: (_, i) {
          final a = actions[i];
          return InkWell(
            onTap: a.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(a.icon, color: a.color, size: 22)),
                const SizedBox(height: 8),
                Text(a.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ── Notification composer ──
  Widget _buildNotificationComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.campaign_rounded, color: AppColors.primary), SizedBox(width: 8), Text('Send Notification', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 6),
        Text('Server push via OneSignal → all subscribed users. Even if app closed for weeks.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
        const SizedBox(height: 14),
        TextField(controller: _ideaController, minLines: 1, maxLines: 2, decoration: InputDecoration(labelText: 'AI idea / topic', hintText: 'e.g. kal vocabulary test...', prefixIcon: const Icon(Icons.auto_awesome_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _generating ? null : _generateNotificationWithAi, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_rounded), label: Text(_generating ? 'AI writing...' : 'Write with AI'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        const SizedBox(height: 12),
        TextField(controller: _titleController, decoration: InputDecoration(labelText: 'Title', prefixIcon: const Icon(Icons.title_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 12),
        TextField(controller: _bodyController, maxLines: 3, decoration: InputDecoration(labelText: 'Message', prefixIcon: const Icon(Icons.message_rounded), alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 12),
        TextField(controller: _linkController, decoration: InputDecoration(labelText: 'Link (optional)', hintText: 'https://...', prefixIcon: const Icon(Icons.link_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _sending ? null : () => _sendAnnouncement(_students), icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded), label: Text(_sending ? 'Sending...' : 'Send to $_students students'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      ]),
    );
  }

  // ── Users section (paginated, searchable) ──
  Widget _buildUsersSection(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.people_alt_rounded, color: AppColors.primary), const SizedBox(width: 8),
        Text('Users (${_filteredUsers.length}${_hasMore ? '+' : ''})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (_usersLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _searchController,
        decoration: InputDecoration(hintText: 'Search name or email (in loaded page)...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), contentPadding: const EdgeInsets.symmetric(vertical: 12)),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
      const SizedBox(height: 10),
      Text('Showing ${_users.length} loaded • Tap Load more for next $_pageSize', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
      const SizedBox(height: 12),
      if (_usersLoading && _users.isEmpty)
        ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _skel(isDark))),
      ..._filteredUsers.map((u) => _buildUserTile(u, isDark)),
      const SizedBox(height: 12),
      if (_hasMore && !_usersLoading)
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _usersLoadingMore ? null : () => _loadUsers(reset: false), icon: _usersLoadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more_rounded), label: Text(_usersLoadingMore ? 'Loading...' : 'Load more ($_pageSize)'))),
      if (!_hasMore && _users.isNotEmpty)
        Center(child: Text('All users loaded ✓', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
    ]);
  }

  Widget _buildUserTile(UserModel user, bool isDark) {
    final roleColor = user.role == 'admin' ? AppColors.purpleGradient.first : AppColors.secondary;
    return Card(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: roleColor.withValues(alpha: 0.12), backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null, child: user.photoUrl.isEmpty ? Text(_initials(user.name), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)) : null),
        title: Text(user.name.isEmpty ? 'Unnamed' : user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${user.email}\nJoined: ${_formatDate(user.joinedAt)} • Lv ${user.currentLevel}', style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserDetailScreen(user: user))),
        trailing: PopupMenuButton<String>(initialValue: user.role, onSelected: (r) => _changeRole(user, r), itemBuilder: (_) => const [PopupMenuItem(value: 'student', child: Text('Make Student')), PopupMenuItem(value: 'admin', child: Text('Make Admin'))], child: Chip(label: Text(user.role.toUpperCase()), labelStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold), backgroundColor: roleColor)),
      ),
    );
  }

  Widget _skel(bool isDark) => Container(height: 72, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)));

  // ── Actions ──
  Future<void> _sendAnnouncement(int studentCount) async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) { _showSnack('Title and message required.', isError: true); return; }
    final link = _linkController.text.trim();
    final actionUrl = link.isNotEmpty ? link : null;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Send Notification'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Send to $studentCount students?', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 12), _previewField('Title', title), const SizedBox(height: 6), _previewField('Message', body), if (actionUrl != null) ...[const SizedBox(height: 6), _previewField('Link', actionUrl)]]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Send Now', style: TextStyle(color: Colors.white)))]));
    if (confirmed != true) return;
    setState(() => _sending = true);
    var firestoreDocId = '';
    try { firestoreDocId = await _repository.sendNotification(title: title, body: body, link: actionUrl, targetRole: 'student', targetCount: studentCount); } catch (e) { debugPrint('Firestore save failed: $e'); }
    final pushResult = await _repository.sendPushNotification(title: title, body: body, link: actionUrl, firestoreDocId: firestoreDocId.isNotEmpty ? firestoreDocId : null);
    _titleController.clear(); _bodyController.clear(); _linkController.clear();
    if (pushResult) { _showSnack('✅ Push sent to $studentCount students!'); } else { _showSnack('⚠️ Saved but push failed. Check OneSignal config.', isError: true); }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _generateNotificationWithAi() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) { _showSnack('AI idea/topic dao first.', isError: true); return; }
    setState(() => _generating = true);
    try {
      final response = await _repository.generateNotificationContent(idea);
      final g = _parseAiNotification(response);
      _titleController.text = g.$1; _bodyController.text = g.$2;
      _showSnack('AI ready — review kore send koro.');
    } catch (e) {
      final fallback = _buildFallbackAiMessage(idea);
      _titleController.text = fallback.$1; _bodyController.text = fallback.$2;
      _showSnack('AI failed: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    } finally { if (mounted) setState(() => _generating = false); }
  }

  (String, String) _parseAiNotification(String response) {
    final lines = response.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    var title = ''; var body = '';
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.startsWith('TITLE:')) title = line.substring(line.indexOf(':') + 1).trim();
      else if (upper.startsWith('BODY:')) body = line.substring(line.indexOf(':') + 1).trim();
      else if (body.isNotEmpty) body = '$body ${line.trim()}';
    }
    if (title.isEmpty || body.isEmpty) {
      final clean = response.replaceAll(RegExp(r'[*#`>-]'), '').trim();
      final parts = clean.split(RegExp(r'\n+'));
      title = parts.isNotEmpty ? parts.first.trim() : '📢 New Update!'; body = parts.length > 1 ? parts.skip(1).join(' ').trim() : clean;
    }
    if (title.length > 55) title = '${title.substring(0, 52)}...'; if (body.length > 180) body = '${body.substring(0, 177)}...';
    return (title.isEmpty ? '📢 New Update!' : title, body.isEmpty ? 'Open the app and keep learning! 🚀' : body);
  }
  (String, String) _buildFallbackAiMessage(String idea) { final c = idea.length > 120 ? '${idea.substring(0, 117)}...' : idea; return ('📢 Important Update!', '$c ✨ Keep practicing today! 🚀'); }
  Future<void> _changeRole(UserModel user, String role) async { if (user.role == role) return; try { await _repository.updateUserRole(user.id, role); _showSnack('${user.name.isEmpty ? user.email : user.name} is now $role.'); } catch (e) { _showSnack('Failed: $e', isError: true); } }
  void _showInfo() => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Admin Panel'), content: const Text('Firestore users/{uid}.role = "admin" once. Push needs OneSignal AppId/ApiKey in Config/app_settings → onesignal.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  Widget _previewField(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 14))]);
  void _showSnack(String m, {bool isError = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? AppColors.error : AppColors.success, behavior: SnackBarBehavior.floating)); }
  String _initials(String name) { final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(); if (p.isEmpty) return 'U'; if (p.length == 1) return p.first.characters.first.toUpperCase(); return '${p.first.characters.first}${p.last.characters.first}'.toUpperCase(); }
  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _ActionItem {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  _ActionItem(this.label, this.icon, this.color, this.onTap);
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  @override
  Widget build(BuildContext context) => const Row(children: [Expanded(child: _Skel(height: 90)), SizedBox(width: 10), Expanded(child: _Skel(height: 90)), SizedBox(width: 10), Expanded(child: _Skel(height: 90))]);
}

class _Skel extends StatelessWidget {
  final double height; final double width;
  const _Skel({this.height = 16, this.width = double.infinity});
  @override
  Widget build(BuildContext context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Container(width: width, height: height, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14))); }
}
