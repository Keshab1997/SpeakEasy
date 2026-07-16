import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../services/ai_service.dart';
import '../../../services/notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../feedback/screens/feedback_screen.dart';
import 'privacy_security_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _dailyWordNotification = true;
  bool _practiceReminderNotification = true;
  bool _streakNotification = true;
  bool _reEngagementNotification = true;
  bool _idleReminderEnabled = true;
  int _idleReminderFrequency = 4;
  bool _idleReminderSoundEnabled = true;
  String _selectedLanguage = 'English (US)';
  List<Map<String, dynamic>> _aiKeys = [];

  @override
  void initState() {
    super.initState();
    _darkMode = HiveService.isDarkMode();
    _notifications = HiveService.isNotificationEnabled();
    _dailyWordNotification = HiveService.isDailyWordNotification();
    _practiceReminderNotification = HiveService.isPracticeReminderNotification();
    _streakNotification = HiveService.isStreakNotification();
    _reEngagementNotification = HiveService.isReEngagementEnabled();
    _idleReminderEnabled = HiveService.isIdleReminderEnabled();
    _idleReminderFrequency = HiveService.getIdleReminderFrequencyHours();
    _idleReminderSoundEnabled = HiveService.isIdleReminderSoundEnabled();
    _loadAiKeys();
  }

  void _loadAiKeys() {
    setState(() => _aiKeys = HiveService.getAiKeys());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider).asData?.value;
    final isAdmin = currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin) ...[
              Text('Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
              const SizedBox(height: 8),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
                  title: const Text('Admin Panel'),
                  subtitle: const Text('Manage students, roles, and notifications'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),
            ],
            Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Switch between light and dark theme'),
                secondary: Icon(_darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                value: _darkMode,
                onChanged: (val) {
                  setState(() => _darkMode = val);
                  HiveService.setDarkMode(val);
                  ref.read(themeModeProvider.notifier).state =
                      val ? ThemeMode.dark : ThemeMode.light;
                },
                activeColor: AppColors.primary,
              ),
            ]),
            const SizedBox(height: 24),
            Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Master toggle for all notifications'),
                secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                value: _notifications,
                onChanged: (val) async {
                  setState(() => _notifications = val);
                  await NotificationService().updateNotificationEnabled(val);
                },
                activeColor: AppColors.primary,
              ),
              if (_notifications) ...[
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('📖 Word of the Day'),
                  subtitle: const Text('Daily vocabulary at 9:00 AM'),
                  value: _dailyWordNotification,
                  onChanged: (val) async {
                    setState(() => _dailyWordNotification = val);
                    await HiveService.setDailyWordNotification(val);
                    await NotificationService().rescheduleOnAppOpen();
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('⏰ Practice Reminder'),
                  subtitle: const Text('Reminder to practice at 7:00 PM'),
                  value: _practiceReminderNotification,
                  onChanged: (val) async {
                    setState(() => _practiceReminderNotification = val);
                    await HiveService.setPracticeReminderNotification(val);
                    await NotificationService().rescheduleOnAppOpen();
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('🔥 Streak Reminder'),
                  subtitle: const Text('Milestone streak celebrations'),
                  value: _streakNotification,
                  onChanged: (val) async {
                    setState(() => _streakNotification = val);
                    await HiveService.setStreakNotification(val);
                    await NotificationService().rescheduleOnAppOpen();
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('🔔 Re-engagement'),
                  subtitle: const Text('Get notified to return when inactive'),
                  value: _reEngagementNotification,
                  onChanged: (val) async {
                    setState(() => _reEngagementNotification = val);
                    await HiveService.setReEngagementEnabled(val);
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('\u23f3 Idle Reminder'),
                  subtitle: const Text('Duolingo-style reminder when inactive'),
                  secondary: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  value: _idleReminderEnabled,
                  onChanged: (val) async {
                    setState(() => _idleReminderEnabled = val);
                    await HiveService.setIdleReminderEnabled(val);
                  },
                  activeColor: AppColors.primary,
                ),
                if (_idleReminderEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                    title: const Text('Reminder Frequency'),
                    subtitle: Text('Every $_idleReminderFrequency hours'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: _idleReminderFrequency.toDouble(),
                        min: 2,
                        max: 24,
                        divisions: 5,
                        label: '$_idleReminderFrequency hours',
                        onChanged: (val) async {
                          setState(() => _idleReminderFrequency = val.round());
                          await HiveService.setIdleReminderFrequencyHours(val.round());
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('\ud83d\udd0a Reminder Sound'),
                    subtitle: const Text('Play custom notification sound'),
                    secondary: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                    value: _idleReminderSoundEnabled,
                    onChanged: (val) async {
                      setState(() => _idleReminderSoundEnabled = val);
                      await HiveService.setIdleReminderSoundEnabled(val);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ],
            ]),
            if (!_notifications) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Enable notifications to get daily vocabulary words and practice reminders.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                title: const Text('Learning Language'),
                subtitle: Text(_selectedLanguage),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: ['English (US)', 'English (UK)', 'English (AU)'].map((lang) {
                        return ListTile(
                          title: Text(lang),
                          trailing: lang == _selectedLanguage ? const Icon(Icons.check, color: AppColors.primary) : null,
                          onTap: () {
                            setState(() => _selectedLanguage = lang);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            Text('AI Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('Use Admin API Keys'),
                subtitle: const Text('Auto-configured keys provided by admin'),
                secondary: const Icon(Icons.cloud_done_rounded),
                value: HiveService.getUseApiKeyManager(),
                onChanged: (val) async {
                  await HiveService.setUseApiKeyManager(val);
                  setState(() {});
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ]),
            const SizedBox(height: 24),
            Text('Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.feedback_rounded, color: AppColors.primary),
                title: const Text('Send Feedback'),
                subtitle: const Text('Help us improve the app'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.security_rounded, color: AppColors.primary),
                title: const Text('Privacy & Security'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),
            Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAiKeysList(bool isDark) {
    return _buildSettingsCard([
      if (_aiKeys.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: Text('No API keys saved yet. Tap below to add one.',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13)),
          ),
        )
      else
        ..._aiKeys.asMap().entries.map((entry) {
          final idx = entry.key;
          final key = entry.value;
          final isActive = key['isActive'] == true;
          final maskedKey = _maskKey(key['key'] as String);
          final name = key['name'] as String? ?? 'Key ${idx + 1}';
          return Column(
            children: [
              if (idx > 0) const Divider(height: 1),
              InkWell(
                onTap: () {
                  if (!isActive) {
                    HiveService.setActiveAiKey(key['id'] as String);
                    _loadAiKeys();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.vpn_key_rounded,
                            color: isActive ? AppColors.primary : Colors.grey, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                if (isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Active', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(maskedKey, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                        onSelected: (val) async {
                          if (val == 'edit') {
                            _showAddKeyDialog(existingKey: key);
                          } else if (val == 'test') {
                            _testKey(key['id'] as String);
                          } else if (val == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Key'),
                                content: Text('Delete "$name"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await HiveService.deleteAiKey(key['id'] as String);
                              _loadAiKeys();
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'test', child: Row(children: [Icon(Icons.wifi_find_rounded, size: 18), SizedBox(width: 8), Text('Test')])),
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      const Divider(height: 1),
      InkWell(
        onTap: () => _showAddKeyDialog(),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 6),
              Text('Add API Key', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    ]);
  }

  void _showAddKeyDialog({Map<String, dynamic>? existingKey}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ApiKeyForm(
        existingKey: existingKey,
        draft: existingKey == null ? HiveService.getApiKeyDraft() : null,
        onSaved: _loadAiKeys,
      ),
    );
  }

  Future<void> _testKey(String id) async {
    final active = HiveService.getActiveAiKey();
    if (active?['id'] != id) {
      await HiveService.setActiveAiKey(id);
      _loadAiKeys();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...'), behavior: SnackBarBehavior.floating),
    );
    final ok = await AIService().testConnection();
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection successful!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection failed. Check API key or URL.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }
}

class _ApiKeyForm extends StatefulWidget {
  final Map<String, dynamic>? existingKey;
  final Map<String, String>? draft;
  final VoidCallback onSaved;

  const _ApiKeyForm({required this.existingKey, this.draft, required this.onSaved});

  @override
  State<_ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends State<_ApiKeyForm> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _keyCtl;
  late final TextEditingController _urlCtl;
  late final TextEditingController _modelCtl;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nameCtl = TextEditingController(
      text: widget.existingKey?['name'] as String? ?? d?['name'] ?? '',
    );
    _keyCtl = TextEditingController(
      text: widget.existingKey?['key'] as String? ?? d?['key'] ?? '',
    );
    _urlCtl = TextEditingController(
      text: widget.existingKey?['baseUrl'] as String? ?? d?['baseUrl'] ?? 'https://api.chatanywhere.tech/v1',
    );
    _modelCtl = TextEditingController(
      text: widget.existingKey?['model'] as String? ?? d?['model'] ?? 'gpt-4o-mini',
    );
    _nameCtl.addListener(_onFieldChanged);
    _keyCtl.addListener(_onFieldChanged);
    _urlCtl.addListener(_onFieldChanged);
    _modelCtl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (widget.existingKey != null) return;
    HiveService.saveApiKeyDraft({
      'name': _nameCtl.text,
      'key': _keyCtl.text,
      'baseUrl': _urlCtl.text,
      'model': _modelCtl.text,
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _keyCtl.dispose();
    _urlCtl.dispose();
    _modelCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existingKey != null ? 'Edit API Key' : 'Add API Key',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtl,
              decoration: InputDecoration(
                labelText: 'Key Name',
                hintText: 'e.g. ChatAnywhere Free',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtl,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.chatanywhere.tech/v1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtl,
              decoration: InputDecoration(
                labelText: 'Model',
                hintText: 'e.g. gpt-4o-mini, ~openai/gpt-latest',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.model_training_rounded, size: 18, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            _ModelChips(
              selected: _modelCtl.text,
              onTap: (model) => setState(() => _modelCtl.text = model),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _save,
                child: Text(widget.existingKey != null ? 'Save Changes' : 'Add Key'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final id = widget.existingKey?['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final name = _nameCtl.text.trim();
    final key = _keyCtl.text.trim();
    final url = _urlCtl.text.trim();
    final model = _modelCtl.text.trim();

    if (key.isEmpty) return;

    final isActive = widget.existingKey?['isActive'] == true;

    final config = {
      'id': id,
      'name': name.isEmpty ? 'Key ${id.substring(id.length - 4)}' : name,
      'key': key,
      'baseUrl': url.isEmpty ? 'https://api.chatanywhere.tech/v1' : url,
      'model': model.isEmpty ? 'gpt-4o-mini' : model,
      'isActive': isActive,
    };

    if (widget.existingKey == null) {
      final keys = HiveService.getAiKeys();
      config['isActive'] = keys.isEmpty;
    }
    await HiveService.saveAiKey(config);
    await HiveService.clearApiKeyDraft();
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
  }
}

class _ModelChips extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onTap;

  const _ModelChips({required this.selected, required this.onTap});

  @override
  State<_ModelChips> createState() => _ModelChipsState();
}

class _ModelChipsState extends State<_ModelChips> {
  List<Map<String, dynamic>> _freeModels = [];
  bool _loadingFree = false;
  bool _fetchedOnce = false;

  static const _models = {
    'ChatAnywhere': [
      'gpt-4o-mini',
      'gpt-4o',
      'gpt-4.1-mini',
      'gpt-5-mini',
      'gpt-5-nano',
      'deepseek-v3',
      'deepseek-r1',
      'gemini-2.5-flash',
      'claude-sonnet-4-6',
    ],
    'OpenRouter': [
      '~openai/gpt-latest',
      '~anthropic/claude-sonnet-latest',
      '~google/gemini-latest',
      'google/gemini-2.5-flash',
      'openai/gpt-4o',
      'anthropic/claude-sonnet-4',
      'deepseek/deepseek-r1',
      'deepseek/deepseek-v3',
      'meta-llama/llama-4-maverick',
      'mistral/mistral-large',
      'qwen/qwen-2.5-72b',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadCachedFreeModels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_freeModels.isEmpty && !_loadingFree && !_fetchedOnce) {
        _fetchFreeModels();
      }
    });
  }

  void _loadCachedFreeModels() {
    final cached = HiveService.getFreeOpenRouterModels();
    if (cached.isNotEmpty) {
      _freeModels = cached;
      _fetchedOnce = true;
    }
  }

  String _tierEmoji(String tier) {
    switch (tier) {
      case 'fast':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'slow':
        return '🔴';
      default:
        return '';
    }
  }

  Future<void> _fetchFreeModels() async {
    if (_loadingFree) return;
    setState(() => _loadingFree = true);
    try {
      final result = await AIService().fetchFreeOpenRouterModels();
      if (result.isNotEmpty) {
        await HiveService.saveFreeOpenRouterModels(result);
        if (mounted) setState(() => _freeModels = result);
      }
    } catch (_) {
      if (mounted) setState(() => _fetchedOnce = true);
    }
    if (mounted) {
      setState(() {
        _loadingFree = false;
        _fetchedOnce = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: _models.length + 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: [
              ..._models.keys.map((k) => Tab(text: k)),
              const Tab(text: 'Free (OpenRouter)'),
            ],
          ),
          SizedBox(
            height: 44,
            child: TabBarView(
              children: [
                ..._models.values.map((models) => _buildChipRow(models, isDark)),
                _buildFreeModelsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow(List<dynamic> models, bool isDark) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: models.map((m) {
        String id;
        String? emoji;
        if (m is String) {
          id = m;
        } else {
          final map = m as Map<String, dynamic>;
          id = map['id'] as String;
          emoji = _tierEmoji(map['tier'] as String? ?? '');
        }
        final isSelected = id == widget.selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => widget.onTap(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : Colors.grey[300]!),
                ),
              ),
              child: Text(
                emoji != null ? '$emoji $id' : id,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFreeModelsTab(bool isDark) {
    if (_loadingFree) {
      return const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Fetching...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    if (_freeModels.isEmpty) {
      return Center(
        child: GestureDetector(
          onTap: _fetchFreeModels,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_download_rounded,
                    size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Load free models',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }
    return _buildChipRow(_freeModels.cast<dynamic>(), isDark);
  }
}
