import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/admin_api_key.dart';
import '../../../services/ai_service.dart';
import '../../../services/api_key_manager.dart';

class AdminApiKeysScreen extends StatefulWidget {
  const AdminApiKeysScreen({super.key});

  @override
  State<AdminApiKeysScreen> createState() => _AdminApiKeysScreenState();
}

class _AdminApiKeysScreenState extends State<AdminApiKeysScreen> {
  // ── Search / filter / sort state ──
  String _searchQuery = '';
  String _providerFilter = 'all';
  String _statusFilter = 'all';
  String _sortMode = 'priority';
  final Set<String> _revealedKeys = {};

  /// Live cooldown snapshot from ApiKeyManager (device-local), refreshed by
  /// [_cooldownTimer] so the badge stays current while the screen is open.
  List<Map<String, dynamic>> _keyHealth = [];
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _keyHealth = ApiKeyManager.instance.getKeyHealth();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {
          _keyHealth = ApiKeyManager.instance.getKeyHealth();
        });
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            tooltip: 'Add Key',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showKeyDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAlertBanner(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Group configs (provider → enabled/priority). Outer stream so toggling
              // a group re-renders the whole list immediately.
              stream: FirebaseFirestore.instance
                  .collection('admin_key_groups')
                  .snapshots(),
              builder: (context, groupSnapshot) {
                final groupData = <String, Map<String, dynamic>>{};
                for (final d in groupSnapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                  groupData[d.id] = d.data();
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('admin_api_keys')
                      .orderBy('priority', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vpn_key_off_rounded,
                                size: 64,
                                color:
                                    isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 16),
                            Text('No API keys configured.',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Your First Key'),
                              onPressed: () => _showKeyDialog(context),
                            ),
                          ],
                        ),
                      );
                    }

                    // Apply search / provider / status filters, then sort.
                    final filtered = _sortDocs(_filterDocs(docs));

                    // Group the key docs by provider so each provider renders under
                    // its own header (group toggle + priority) instead of one flat
                    // list.
                    final sections = <String,
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                    for (final doc in filtered) {
                      final data = doc.data();
                      final provider = (data['provider'] as String?) ??
                          AdminApiKey.inferProvider(
                              data['baseUrl'] as String? ?? '');
                      sections.putIfAbsent(provider, () => []).add(doc);
                    }
                    final providers = sections.keys.toList()
                      ..sort((a, b) {
                        final ap = groupData[a]?['priority'] as int? ?? 100;
                        final bp = groupData[b]?['priority'] as int? ?? 100;
                        return ap.compareTo(bp);
                      });

                    final items = <Widget>[];
                    for (final provider in providers) {
                      items.add(_buildGroupHeader(provider, groupData[provider],
                          sections[provider]!.length));
                      for (final doc in sections[provider]!) {
                        items.add(_buildKeyCard(doc));
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryHeader(docs),
                        _buildControls(),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    'No keys match your filters.',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54),
                                  ),
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: items,
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Search / filter / sort helpers ──

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final query = _searchQuery.trim().toLowerCase();
    return docs.where((doc) {
      final d = doc.data();
      final provider = (d['provider'] as String?) ??
          AdminApiKey.inferProvider(d['baseUrl'] as String? ?? '');
      if (_providerFilter != 'all' && provider != _providerFilter) return false;
      if (_statusFilter != 'all') {
        final active = d['isActive'] as bool? ?? true;
        if (active != (_statusFilter == 'active')) return false;
      }
      if (query.isNotEmpty) {
        final name = (d['name'] as String? ?? '').toLowerCase();
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    switch (_sortMode) {
      case 'usage':
        sorted.sort((a, b) => ((b.data()['usageCount'] as int?) ?? 0)
            .compareTo((a.data()['usageCount'] as int?) ?? 0));
        break;
      case 'errors':
        sorted.sort((a, b) => ((b.data()['errorCount'] as int?) ?? 0)
            .compareTo((a.data()['errorCount'] as int?) ?? 0));
        break;
      default:
        sorted.sort((a, b) => ((a.data()['priority'] as int?) ?? 1)
            .compareTo((b.data()['priority'] as int?) ?? 1));
    }
    return sorted;
  }

  // ── Summary header + controls ──

  /// Compact aggregate stats for the admin: total/active keys, usage, errors.
  Widget _buildSummaryHeader(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var active = 0, usage = 0, errors = 0;
    for (final doc in docs) {
      final d = doc.data();
      if (d['isActive'] as bool? ?? true) active++;
      usage += d['usageCount'] as int? ?? 0;
      errors += d['errorCount'] as int? ?? 0;
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            _summaryStat('${docs.length}', 'Keys'),
            _summaryStat('$active', 'Active'),
            _summaryStat('$usage', 'Usage'),
            _summaryStat('$errors', 'Errors'),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  /// Search field + sort dropdown + provider/status filter chips.
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search keys...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortMode,
                items: const [
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                  DropdownMenuItem(value: 'usage', child: Text('Usage')),
                  DropdownMenuItem(value: 'errors', child: Text('Errors')),
                ],
                onChanged: (v) => setState(() => _sortMode = v ?? 'priority'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('provider', _providerFilter, 'all', 'All Providers'),
              _filterChip(
                  'provider', _providerFilter, 'openrouter', 'OpenRouter'),
              _filterChip('provider', _providerFilter, 'google', 'Google'),
              _filterChip('provider', _providerFilter, 'custom', 'Custom'),
            ]),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('status', _statusFilter, 'all', 'All Status'),
              _filterChip('status', _statusFilter, 'active', 'Active'),
              _filterChip('status', _statusFilter, 'inactive', 'Inactive'),
            ]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterChip(String group, String current, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: current == value,
        onSelected: (_) => setState(() {
          if (group == 'provider') {
            _providerFilter = value;
          } else {
            _statusFilter = value;
          }
        }),
      ),
    );
  }

  /// Red banner when ApiKeyManager has flagged all keys as failed. Streams the
  /// alert doc so it appears/disappears live; dismiss marks it resolved.
  Widget _buildAlertBanner(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_alerts')
          .doc('api_keys_failed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data()!;
        if (data['resolved'] == true) return const SizedBox.shrink();
        return Material(
          color: Colors.red.shade700,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['message'] as String? ?? 'All API keys failed.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _dismissAlert,
                  child: const Text('Dismiss',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _dismissAlert() async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_alerts')
          .doc('api_keys_failed')
          .set({'resolved': true}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  Future<void> _copyKey(String key) async {
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Key copied to clipboard'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Quick enable/disable from the card. Only writes config fields, matching
  /// the Firestore update rule (config-only set).
  Future<void> _toggleKeyActive(String docId, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_api_keys')
          .doc(docId)
          .update({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isOnCooldown(String keyId) {
    for (final h in _keyHealth) {
      if (h['id'] == keyId) return h['isOnCooldown'] == true;
    }
    return false;
  }

  /// Bottom sheet with the most recent error logs for a key.
  void _showErrorLogs(String keyId, String keyName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error Logs — $keyName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('api_error_logs')
                    .where('keyId', isEqualTo: keyId)
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final logs = snapshot.data!.docs;
                  if (logs.isEmpty) {
                    return const Center(
                        child: Text('No error logs for this key.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = logs[i].data();
                      final status = d['statusCode'] as int? ?? 0;
                      final type = d['errorType'] as String? ?? 'unknown';
                      final message = d['message'] as String? ?? '';
                      final ts = (d['timestamp'] as Timestamp?)?.toDate();
                      return ListTile(
                        dense: true,
                        leading: Icon(
                            status >= 500 ? Icons.error : Icons.warning,
                            color: status >= 500 ? Colors.red : Colors.orange),
                        title: Text(message),
                        subtitle: Text(
                          '${ts != null ? _formatTime(ts) : '—'} · $type (HTTP $status)',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $h:$m';
  }

  /// Provider group header: name, key count, priority (lower = tried first)
  /// and a master enable/disable switch for the whole group.
  Widget _buildGroupHeader(
      String provider, Map<String, dynamic>? config, int keyCount) {
    final enabled = config?['enabled'] as bool? ?? true;
    final priority = config?['priority'] as int? ?? 100;
    final name =
        config?['name'] as String? ?? AdminApiKey.providerName(provider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      color: enabled
          ? (isDark ? Colors.blueGrey[800] : Colors.blueGrey[50])
          : (isDark ? Colors.grey[850] : Colors.grey[200]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.bolt_rounded : Icons.cloud_off_rounded,
              size: 20,
              color: enabled ? Colors.amber : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('$keyCount key(s) · priority $priority (lower = first)',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cooldown settings',
              icon: const Icon(Icons.settings_rounded, size: 20),
              onPressed: () => _showGroupSettings(provider, config),
            ),
            IconButton(
              tooltip: 'Lower priority (tried first)',
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: priority > 1
                  ? () => _saveGroupConfig(provider, priority: priority - 1)
                  : null,
            ),
            IconButton(
              tooltip: 'Higher priority (tried later)',
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () =>
                  _saveGroupConfig(provider, priority: priority + 1),
            ),
            Switch(
              value: enabled,
              onChanged: (v) => _saveGroupConfig(provider, enabled: v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isActive = data['isActive'] as bool? ?? true;
    final name = data['name'] as String? ?? 'Key';
    final model = data['model'] as String? ?? 'gpt-4o-mini';
    final provider = (data['provider'] as String?) ??
        AdminApiKey.inferProvider(data['baseUrl'] as String? ?? '');
    final maskedKey = _maskKey(data['key'] as String? ?? '');
    final priority = data['priority'] as int? ?? 1;
    final usage = data['usageCount'] as int? ?? 0;
    final errors = data['errorCount'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.vpn_key_rounded : Icons.vpn_key_off_rounded,
                  color: isActive ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Copy full key to clipboard.
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _copyKey(data['key'] as String? ?? ''),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.copy_rounded,
                        size: 16, color: Colors.grey[600]),
                  ),
                ),
                // Reveal / hide the full key.
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    if (_revealedKeys.contains(doc.id)) {
                      _revealedKeys.remove(doc.id);
                    } else {
                      _revealedKeys.add(doc.id);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _revealedKeys.contains(doc.id)
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showKeyDialog(context,
                      docId: doc.id, existingData: data),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_rounded,
                        size: 16, color: Colors.grey[600]),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _confirmDelete(context, doc.id, name),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child:
                        Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                  ),
                ),
                Tooltip(
                  message: 'Toggle active',
                  child: Switch(
                    value: isActive,
                    onChanged: (v) => _toggleKeyActive(doc.id, v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Provider', AdminApiKey.providerName(provider)),
            _infoRow('Model', model),
            _infoRow(
                'Key',
                _revealedKeys.contains(doc.id)
                    ? (data['key'] as String? ?? '')
                    : maskedKey),
            _infoRow('Priority', priority.toString()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statChip('✓ $usage', Colors.green),
                    _statChip(
                        '✗ $errors', errors > 0 ? Colors.red : Colors.grey),
                    if (_isOnCooldown(doc.id))
                      _statChip('⏳ cooldown', Colors.orange),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Test Connection',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _testKey(
                    provider,
                    data['baseUrl'] as String? ?? '',
                    data['key'] as String? ?? '',
                    data['model'] as String? ?? '',
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Logs', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showErrorLogs(doc.id, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Creates/updates a group config doc in Firestore (merge semantics), so a
  /// missing doc (fresh setup / legacy keys) gets sensible defaults. Always
  /// writes name/enabled/priority so a fresh doc passes the create rule
  /// (which requires all three fields) instead of relying on merge defaults.
  Future<void> _saveGroupConfig(String provider,
      {bool? enabled, int? priority}) async {
    final data = <String, dynamic>{
      'name': AdminApiKey.providerName(provider),
      'enabled': enabled ?? true,
      'priority': priority ?? 100,
    };
    try {
      await FirebaseFirestore.instance
          .collection('admin_key_groups')
          .doc(provider)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Bottom sheet to tune per-provider cooldown durations (seconds). An empty
  /// field resets that cooldown to the built-in default (deleted from the doc).
  void _showGroupSettings(String provider, Map<String, dynamic>? config) {
    final name =
        config?['name'] as String? ?? AdminApiKey.providerName(provider);
    final rateCtl = TextEditingController(
        text: (config?['rateLimitCooldownSeconds'] as int?)?.toString() ?? '');
    final serverCtl = TextEditingController(
        text:
            (config?['serverErrorCooldownSeconds'] as int?)?.toString() ?? '');
    final defaultCtl = TextEditingController(
        text: (config?['defaultCooldownSeconds'] as int?)?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cooldown Settings — $name',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Empty field = built-in default.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              _cooldownField(
                  rateCtl, 'Rate-limit (429)', 'seconds, default 60'),
              const SizedBox(height: 12),
              _cooldownField(
                  serverCtl, 'Server error (5xx)', 'seconds, default 120'),
              const SizedBox(height: 12),
              _cooldownField(defaultCtl, 'Other errors', 'seconds, default 30'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                  onPressed: () async {
                    final rate = int.tryParse(rateCtl.text.trim());
                    final server = int.tryParse(serverCtl.text.trim());
                    final def = int.tryParse(defaultCtl.text.trim());
                    if ((rate != null && rate < 1) ||
                        (server != null && server < 1) ||
                        (def != null && def < 1)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Cooldowns must be positive seconds'),
                            backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    try {
                      // Include name/enabled/priority so a fresh doc passes
                      // the create rule; FieldValue.delete() resets a field to
                      // the built-in default.
                      final data = <String, dynamic>{
                        'name': AdminApiKey.providerName(provider),
                        'enabled': config?['enabled'] as bool? ?? true,
                        'priority': config?['priority'] as int? ?? 100,
                        'rateLimitCooldownSeconds': rate ?? FieldValue.delete(),
                        'serverErrorCooldownSeconds':
                            server ?? FieldValue.delete(),
                        'defaultCooldownSeconds': def ?? FieldValue.delete(),
                      };
                      await FirebaseFirestore.instance
                          .collection('admin_key_groups')
                          .doc(provider)
                          .set(data, SetOptions(merge: true));
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cooldownField(TextEditingController ctl, String label, String hint) {
    return TextField(
      controller: ctl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  void _showKeyDialog(BuildContext context,
      {String? docId, Map<String, dynamic>? existingData}) {
    final nameCtl =
        TextEditingController(text: existingData?['name'] as String? ?? '');
    final keyCtl =
        TextEditingController(text: existingData?['key'] as String? ?? '');
    final urlCtl = TextEditingController(
        text: existingData?['baseUrl'] as String? ??
            'https://openrouter.ai/api/v1');
    final modelCtl = TextEditingController(
        text: existingData?['model'] as String? ?? 'gpt-4o-mini');
    final priorityCtl = TextEditingController(
        text: (existingData?['priority'] as int?)?.toString() ?? '1');
    String provider = (existingData?['provider'] as String?) ??
        AdminApiKey.inferProvider(existingData?['baseUrl'] as String? ?? '');
    bool isActive = existingData?['isActive'] as bool? ?? true;
    bool fetchingModels = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existingData != null ? 'Edit API Key' : 'Add API Key',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: provider,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'openrouter', child: Text('OpenRouter')),
                      DropdownMenuItem(
                          value: 'google', child: Text('Google AI Studio')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        provider = v;
                        // Pre-fill sensible base URL/model per provider.
                        if (v == 'google') {
                          urlCtl.text =
                              'https://generativelanguage.googleapis.com/v1beta';
                          modelCtl.text = 'gemini-2.5-flash';
                        } else if (v == 'openrouter') {
                          urlCtl.text = 'https://openrouter.ai/api/v1';
                          modelCtl.text = 'gpt-4o-mini';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Key Name',
                      hintText: 'e.g. OpenRouter Free',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-or-v1-...',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://openrouter.ai/api/v1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: modelCtl,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: 'gpt-4o-mini',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (provider == 'openrouter') ...[
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: fetchingModels
                              ? null
                              : () async {
                                  setDialogState(() => fetchingModels = true);
                                  final models = await AIService()
                                      .fetchFreeOpenRouterModels(
                                          apiKey: keyCtl.text.trim());
                                  setDialogState(() => fetchingModels = false);
                                  if (!ctx.mounted) return;
                                  if (models.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'No free models found. Check your API key or internet connection.'),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  showDialog(
                                    context: ctx,
                                    builder: (c) => SimpleDialog(
                                      title: const Text('Free Models'),
                                      children: models.map((m) {
                                        final id = m['id'] as String;
                                        final tier = m['tier'] as String;
                                        return SimpleDialogOption(
                                          child: Row(children: [
                                            Text(tier == 'fast'
                                                ? '⚡'
                                                : tier == 'medium'
                                                    ? '🔄'
                                                    : '🐢'),
                                            const SizedBox(width: 8),
                                            // FIXED: the model name Text was a rigid
                                            // (non-flexible) Row child, so long ids
                                            // inflated the dialog's intrinsic width and
                                            // overflowed on the right. Expanded lets it
                                            // share the available width; ellipsis keeps it
                                            // inside the dialog on any screen size.
                                            Expanded(
                                              child: Text(
                                                '$id ($tier)',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]),
                                          onPressed: () {
                                            modelCtl.text = id;
                                            Navigator.pop(c);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(ctx).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: fetchingModels
                                ? Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(Icons.download_rounded, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priorityCtl,
                    decoration: const InputDecoration(
                      labelText: 'Priority (lower = tried first)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: Text(existingData != null ? 'Update' : 'Add'),
                      onPressed: () async {
                        final name = nameCtl.text.trim();
                        final key = keyCtl.text.trim();
                        final url = urlCtl.text.trim();
                        final model = modelCtl.text.trim();
                        final priority = int.tryParse(priorityCtl.text.trim());

                        if (name.isEmpty || key.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Name and API Key are required'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        final parsedUrl = Uri.tryParse(url);
                        if (parsedUrl == null ||
                            (parsedUrl.scheme != 'http' &&
                                parsedUrl.scheme != 'https') ||
                            parsedUrl.host.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Base URL must be a valid http(s) URL'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (model.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Model cannot be empty'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        if (priority == null || priority < 1) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Priority must be a positive number'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        final now = Timestamp.fromDate(DateTime.now());
                        // Config-only payload. Stat counters (usageCount,
                        // errorCount, lastUsedAt, lastErrorAt) are managed by
                        // ApiKeyManager + Firestore rules, so an edit must not
                        // rewrite them, and addedBy/createdAt are immutable.
                        final data = <String, dynamic>{
                          'name': name,
                          'key': key,
                          'baseUrl': url,
                          'model': model,
                          'provider': provider,
                          'isActive': isActive,
                          'priority': priority,
                          'updatedAt': now,
                        };

                        try {
                          if (docId != null) {
                            await FirebaseFirestore.instance
                                .collection('admin_api_keys')
                                .doc(docId)
                                .update(data);
                          } else {
                            // New key: bind to the creating admin with zero
                            // stats (rules enforce addedBy == request.auth.uid
                            // and counters == 0 on create).
                            data.addAll({
                              'usageCount': 0,
                              'errorCount': 0,
                              'addedBy':
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                              'createdAt': now,
                            });
                            await FirebaseFirestore.instance
                                .collection('admin_api_keys')
                                .add(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('admin_api_keys')
                  .doc(docId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _testKey(
      String provider, String baseUrl, String key, String model) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No API key to test'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Testing connection...'),
          behavior: SnackBarBehavior.floating),
    );

    // Test the key directly against its own base URL. This never touches the
    // saved user key or the useAdminKeys toggle, so a failed test can't leave
    // the app in a broken key state.
    final ok = await AIService().testConnectionWithKey(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: key,
      model: model,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Connection successful!' : 'Connection failed.'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
