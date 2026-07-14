import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminErrorLogsScreen extends StatefulWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  State<AdminErrorLogsScreen> createState() => _AdminErrorLogsScreenState();
}

class _AdminErrorLogsScreenState extends State<AdminErrorLogsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'all', child: Text('All',
                  style: TextStyle(fontWeight: _filter == 'all' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'rate_limit', child: Text('Rate Limits',
                  style: TextStyle(fontWeight: _filter == 'rate_limit' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'auth_error', child: Text('Auth Errors',
                  style: TextStyle(fontWeight: _filter == 'auth_error' ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(value: 'server_error', child: Text('Server Errors',
                  style: TextStyle(fontWeight: _filter == 'server_error' ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('api_error_logs')
            .orderBy('timestamp', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          if (_filter != 'all') {
            docs = docs.where((d) => d.data()['errorType'] == _filter).toList();
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64,
                      color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text('No errors logged.',
                      style: TextStyle(fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            );
          }

          final all = snapshot.data!.docs;
          final rateLimitCount = all.where((d) => d.data()['errorType'] == 'rate_limit').length;
          final authErrorCount = all.where((d) => d.data()['errorType'] == 'auth_error').length;
          final serverErrorCount = all.where((d) => d.data()['errorType'] == 'server_error').length;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total', all.length.toString(), Colors.grey),
                    _statItem('Rate Limit', rateLimitCount.toString(), Colors.orange),
                    _statItem('Auth', authErrorCount.toString(), Colors.red),
                    _statItem('Server', serverErrorCount.toString(), Colors.purple),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final errorType = data['errorType'] as String? ?? 'unknown';
                    final keyName = data['keyName'] as String? ?? 'Unknown';
                    final feature = data['feature'] as String? ?? '';
                    final statusCode = data['statusCode'] as int? ?? 0;
                    final message = data['message'] as String? ?? '';
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final retried = data['retried'] as bool? ?? false;
                    final retrySuccess = data['retrySuccess'] as bool? ?? false;

                    final icon = switch (errorType) {
                      'rate_limit' => Icons.speed_rounded,
                      'auth_error' => Icons.lock_rounded,
                      'server_error' => Icons.dns_rounded,
                      _ => Icons.error_outline_rounded,
                    };
                    final color = switch (errorType) {
                      'rate_limit' => Colors.orange,
                      'auth_error' => Colors.red,
                      'server_error' => Colors.purple,
                      _ => Colors.grey,
                    };
                    final severity = switch (errorType) {
                      'rate_limit' => '⚠️',
                      'auth_error' => '🔴',
                      'server_error' => '🟣',
                      _ => 'ℹ️',
                    };

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(icon, color: color),
                        title: Text('$severity $errorType — $keyName',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '$feature | HTTP $statusCode | $message'
                          '${retried ? retrySuccess ? ' | ✅ Retry succeeded' : ' | ❌ Retry failed' : ''}'
                          '\n${_formatTime(timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
