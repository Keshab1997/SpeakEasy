import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/admin_api_key.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';

class AdminApiKeysScreen extends StatefulWidget {
  const AdminApiKeysScreen({super.key});

  @override
  State<AdminApiKeysScreen> createState() => _AdminApiKeysScreenState();
}

class _AdminApiKeysScreenState extends State<AdminApiKeysScreen> {
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                      Icon(Icons.vpn_key_off_rounded, size: 64,
                          color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('No API keys configured.',
                          style: TextStyle(fontSize: 16,
                              color: isDark ? Colors.white60 : Colors.black54)),
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

              // Group the key docs by provider so each provider renders under
              // its own header (group toggle + priority) instead of one flat
              // list.
              final sections = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
              for (final doc in docs) {
                final data = doc.data();
                final provider = (data['provider'] as String?) ??
                    AdminApiKey.inferProvider(data['baseUrl'] as String? ?? '');
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
                items.add(_buildGroupHeader(
                    provider, groupData[provider], sections[provider]!.length));
                for (final doc in sections[provider]!) {
                  items.add(_buildKeyCard(doc));
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: items,
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
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
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  /// Provider group header: name, key count, priority (lower = tried first)
  /// and a master enable/disable switch for the whole group.
  Widget _buildGroupHeader(
      String provider, Map<String, dynamic>? config, int keyCount) {
    final enabled = config?['enabled'] as bool? ?? true;
    final priority = config?['priority'] as int? ?? 100;
    final name = config?['name'] as String? ?? AdminApiKey.providerName(provider);
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
              tooltip: 'Lower priority (tried first)',
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: priority > 1
                  ? () => _saveGroupConfig(provider, priority: priority - 1)
                  : null,
            ),
            IconButton(
              tooltip: 'Higher priority (tried later)',
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _saveGroupConfig(provider, priority: priority + 1),
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
                  isActive
                      ? Icons.vpn_key_rounded
                      : Icons.vpn_key_off_rounded,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      _showKeyDialog(context, docId: doc.id, existingData: data),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_rounded, size: 16, color: Colors.grey[600]),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _confirmDelete(context, doc.id, name),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Provider', AdminApiKey.providerName(provider)),
            _infoRow('Model', model),
            _infoRow('Key', maskedKey),
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
                    _statChip('✗ $errors', errors > 0 ? Colors.red : Colors.grey),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Test Connection', style: TextStyle(fontSize: 12)),
                  onPressed: () => _testKey(
                    provider,
                    data['baseUrl'] as String? ?? '',
                    data['key'] as String? ?? '',
                    data['model'] as String? ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Creates/updates a group config doc in Firestore (merge semantics), so a
  /// missing doc (fresh setup / legacy keys) gets sensible defaults.
  Future<void> _saveGroupConfig(String provider,
      {bool? enabled, int? priority}) async {
    final data = <String, dynamic>{'name': AdminApiKey.providerName(provider)};
    if (enabled != null) data['enabled'] = enabled;
    if (priority != null) data['priority'] = priority;
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

  void _showKeyDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final nameCtl = TextEditingController(text: existingData?['name'] as String? ?? '');
    final keyCtl = TextEditingController(text: existingData?['key'] as String? ?? '');
    final urlCtl = TextEditingController(
        text: existingData?['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1');
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
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existingData != null ? 'Edit API Key' : 'Add API Key',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: provider,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter')),
                      DropdownMenuItem(value: 'google', child: Text('Google AI Studio')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() {
                        provider = v;
                        // Pre-fill sensible base URL/model per provider.
                        if (v == 'google') {
                          urlCtl.text = 'https://generativelanguage.googleapis.com/v1beta';
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                final models = await AIService().fetchFreeOpenRouterModels(apiKey: keyCtl.text.trim());
                                setDialogState(() => fetchingModels = false);
                                if (!ctx.mounted) return;
                                if (models.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('No free models found. Check your API key or internet connection.'),
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
                                          Text(tier == 'fast' ? '⚡' : tier == 'medium' ? '🔄' : '🐢'),
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
                            color: Theme.of(ctx).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: fetchingModels
                              ? Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                        if (nameCtl.text.trim().isEmpty || keyCtl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Name and API Key are required'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        final now = Timestamp.fromDate(DateTime.now());
                        final data = <String, dynamic>{
                          'name': nameCtl.text.trim(),
                          'key': keyCtl.text.trim(),
                          'baseUrl': urlCtl.text.trim(),
                          'model': modelCtl.text.trim(),
                          'provider': provider,
                          'isActive': isActive,
                          'priority': int.tryParse(priorityCtl.text.trim()) ?? 1,
                          'usageCount': existingData?['usageCount'] as int? ?? 0,
                          'errorCount': existingData?['errorCount'] as int? ?? 0,
                          'lastErrorAt': existingData?['lastErrorAt'],
                          'lastUsedAt': existingData?['lastUsedAt'],
                          'addedBy': existingData?['addedBy'] ?? HiveService.getUserId() ?? '',
                          'updatedAt': now,
                          'createdAt': existingData?['createdAt'] ?? now,
                        };

                        try {
                          if (docId != null) {
                            await FirebaseFirestore.instance
                                .collection('admin_api_keys')
                                .doc(docId)
                                .update(data);
                          } else {
                            await FirebaseFirestore.instance
                                .collection('admin_api_keys')
                                .add(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  Future<void> _testKey(String provider, String baseUrl, String key, String model) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No API key to test'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), behavior: SnackBarBehavior.floating),
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
