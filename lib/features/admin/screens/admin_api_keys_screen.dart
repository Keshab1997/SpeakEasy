import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isActive = data['isActive'] as bool? ?? true;
              final name = data['name'] as String? ?? 'Key ${index + 1}';
              final model = data['model'] as String? ?? 'gpt-4o-mini';
              final maskedKey = _maskKey(data['key'] as String? ?? '');
              final priority = data['priority'] as int? ?? index + 1;
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
                          if (isActive) ...[
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              onPressed: () => _showKeyDialog(context,
                                  docId: doc.id, existingData: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, size: 18,
                                  color: Colors.red),
                              onPressed: () => _confirmDelete(context, doc.id, name),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow('Model', model),
                      _infoRow('Key', maskedKey),
                      _infoRow('Priority', priority.toString()),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statChip('✓ $usage', Colors.green),
                          const SizedBox(width: 8),
                          _statChip('✗ $errors', errors > 0 ? Colors.red : Colors.grey),
                          const Spacer(),
                          TextButton(
                            child: const Text('Test Connection'),
                            onPressed: () => _testKey(
                              doc.id,
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

  void _showKeyDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final nameCtl = TextEditingController(text: existingData?['name'] as String? ?? '');
    final keyCtl = TextEditingController(text: existingData?['key'] as String? ?? '');
    final urlCtl = TextEditingController(
        text: existingData?['baseUrl'] as String? ?? 'https://openrouter.ai/api/v1');
    final modelCtl = TextEditingController(
        text: existingData?['model'] as String? ?? 'gpt-4o-mini');
    final priorityCtl = TextEditingController(
        text: (existingData?['priority'] as int?)?.toString() ?? '1');
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: fetchingModels
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded),
                        tooltip: 'Fetch free models from OpenRouter',
                        onPressed: () async {
                          setDialogState(() => fetchingModels = true);
                          final models = await AIService().fetchFreeOpenRouterModels();
                          setDialogState(() => fetchingModels = false);
                          if (models.isEmpty || !ctx.mounted) return;
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
                                    Text('$id ($tier)'),
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
                      ),
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

  Future<void> _testKey(String docId, String baseUrl, String key, String model) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No API key to test'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Temporarily save this key as the active user key
    final prevToggle = HiveService.getUseApiKeyManager();
    await HiveService.setUseApiKeyManager(false);
    await HiveService.saveAiKey({
      'id': 'test_$docId',
      'name': 'test',
      'key': key,
      'baseUrl': baseUrl,
      'model': model,
      'isActive': true,
    });
    await HiveService.setActiveAiKey('test_$docId');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), behavior: SnackBarBehavior.floating),
    );

    final ok = await AIService().testConnection();
    await HiveService.setUseApiKeyManager(prevToggle);

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
