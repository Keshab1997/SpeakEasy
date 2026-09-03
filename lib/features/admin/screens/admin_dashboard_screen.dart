import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../models/notification_templates.dart';
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
  bool _winnerLoading = false;
  String _selectedTone = 'funny';
  String? _selectedTemplateId;

  static const _tones = <String, String>{
    'funny': '😄 Funny',
    'motivational': '🔥 Motivational',
    'urgent': '⏳ Urgent',
    'festive': '🎉 Festive',
  };

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

  // ── Notification composer (advanced: templates + AI + winner + tone) ──
  Widget _buildNotificationComposer(bool isDark) {
    final hintColor = isDark ? Colors.white38 : Colors.black38;
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

        // ── 1. Quick templates (no AI needed — always correct) ──
        const Text('⚡ Quick Templates — tap to load', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kNotificationTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = kNotificationTemplates[i];
              final selected = _selectedTemplateId == t.id;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => _applyTemplate(t),
                avatar: Icon(t.icon, size: 16, color: selected ? Colors.white : AppColors.primary),
                label: Text(t.label),
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : hintColor),
                selectedColor: AppColors.primary,
                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // ── 2. One-tap winner announcement (real leaderboard data) ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _winnerLoading || _sending ? null : _sendWinnerNow,
            icon: _winnerLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.emoji_events_rounded, color: Colors.amber),
            label: Text(_winnerLoading ? 'Leaderboard loading...' : '🏆 Ajker Quiz Winner — Name + Score Pathao'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
              side: BorderSide(color: Colors.amber.shade600),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        Text('Aajker quiz er champion er naam + score, automatic message. Roj raat 9 tar scheduled push-o ache (Cloud Function).', style: TextStyle(fontSize: 11, color: hintColor)),
        const SizedBox(height: 12),

        // ── 3. AI writer: idea + tone ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _ideaController,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'AI idea / topic',
                hintText: 'e.g. kal vocabulary test...',
                prefixIcon: const Icon(Icons.auto_awesome_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTone,
              decoration: InputDecoration(
                labelText: 'Tone',
                prefixIcon: const Icon(Icons.tune_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              items: _tones.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _selectedTone = v ?? 'funny'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _generating ? null : _generateNotificationWithAi, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_rounded), label: Text(_generating ? 'AI writing...' : '✍️ Write with AI'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        const SizedBox(height: 12),

        // ── 4. Manual fields ──
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

  /// Loads a template into the composer (instantly correct content).
  void _applyTemplate(NotificationTemplate t) {
    setState(() => _selectedTemplateId = t.id);
    _titleController.text = t.title;
    _bodyController.text = t.body;
    _showSnack('Template loaded — edit kore send koro. Winner-এর real data পেতে উপরের 🏆 button use koro.');
  }

  /// Fetches today's REAL quiz leaderboard top-3 from Firestore, builds the
  /// winner announcement and sends it via OneSignal (one tap from admin).
  Future<void> _sendWinnerNow() async {
    if (_sending || _winnerLoading) return;
    setState(() => _winnerLoading = true);
    try {
      final entries = await _repository.fetchQuizTopEntries(limit: 3);
      if (!mounted) return;
      if (entries.isEmpty) {
        _showSnack('Ajker quiz e ekhono kono participant nei! Push pathano hocche na.', isError: true);
        return;
      }
      final w = entries.first;
      final winnerName = ((w['userName'] as String?) ?? '').trim().isNotEmpty
          ? (w['userName'] as String).trim()
          : 'Champion';
      final score = (w['score'] as num?)?.toInt() ?? 0;
      final correct = (w['correctCount'] as num?)?.toInt();
      String? second;
      int? secondScore;
      if (entries.length > 1) {
        second = ((entries[1]['userName'] as String?) ?? '').trim();
        secondScore = (entries[1]['score'] as num?)?.toInt();
      }
      final msg = buildQuizWinnerMessage(
        dateKey: todayQuizDateKey(),
        winnerName: winnerName,
        score: score,
        correctCount: correct,
        secondName: second,
        secondScore: secondScore,
      );

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Send Quiz Winner Push?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(msg.body, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Text('Top: ${entries.map((e) => (e['userName'] ?? '?')).join(' • ')}', style: const TextStyle(fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Send Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      var firestoreDocId = '';
      try {
        firestoreDocId = await _repository.sendNotification(
          title: msg.title,
          body: msg.body,
          targetRole: 'student',
          targetCount: _students,
        );
      } catch (e) {
        debugPrint('Winner push Firestore save failed: $e');
      }
      final push = await _repository.sendPushNotification(
        title: msg.title,
        body: msg.body,
        firestoreDocId: firestoreDocId.isNotEmpty ? firestoreDocId : null,
      );
      if (firestoreDocId.isNotEmpty) {
        await _repository.updateNotificationOutcome(
          firestoreDocId,
          status: push.success ? 'sent' : 'failed',
          oneSignalId: push.oneSignalId,
          recipients: push.recipients,
          error: push.success ? null : push.detail,
        );
      }
      _showSnack(
        push.success
            ? '🏆 Winner push sent!${push.recipients != null ? ' (${push.recipients} devices)' : ''}'
            : '⚠️ Winner push failed: ${push.detail}',
        isError: !push.success,
      );
    } catch (e) {
      _showSnack('Winner push failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _winnerLoading = false);
    }
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
    // Persist the true outcome on the notification doc (history shows sent/failed)
    if (firestoreDocId.isNotEmpty) {
      await _repository.updateNotificationOutcome(
        firestoreDocId,
        status: pushResult.success ? 'sent' : 'failed',
        oneSignalId: pushResult.oneSignalId,
        recipients: pushResult.recipients,
        error: pushResult.success ? null : pushResult.detail,
      );
    }
    _titleController.clear(); _bodyController.clear(); _linkController.clear();
    if (pushResult.success) {
      final rc = pushResult.recipients;
      _showSnack(rc != null && rc > 0
          ? '✅ Push sent! OneSignal recipients: $rc'
          : '✅ Push sent to OneSignal (recipients: ${rc ?? 'n/a'}).');
    } else {
      _showSnack('⚠️ Push failed: ${pushResult.detail}', isError: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _generateNotificationWithAi() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) { _showSnack('AI idea/topic dao first.', isError: true); return; }
    setState(() => _generating = true);
    try {
      final result = await _repository.generateNotificationContent(idea, tone: _selectedTone);
      _titleController.text = result.title;
      _bodyController.text = result.body;
      if (result.fallbackUsed) {
        _showSnack('⚠️ AI not responding — best-matching template use hoyeche. Edit kore send koro.', isError: true);
      } else {
        _showSnack('✅ AI ready — review kore send koro.');
      }
    } catch (e) {
      // Last-resort safety net: a template always beats a broken AI message.
      final tpl = bestTemplateForIdea(idea);
      _titleController.text = tpl.title;
      _bodyController.text = tpl.body;
      _showSnack('AI failed (${e.toString().replaceFirst('Exception: ', '')}) — template use hoyeche.', isError: true);
    } finally { if (mounted) setState(() => _generating = false); }
  }
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
  final double height;
  const _Skel({this.height = 16});
  @override
  Widget build(BuildContext context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Container(width: double.infinity, height: height, decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14))); }
}
