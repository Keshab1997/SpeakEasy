import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/consent_service.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../feedback/screens/feedback_screen.dart';
import 'battery_optimization_screen.dart';
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
  String _appVersion = '';
  bool _privacyOptionsRequired = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadPrivacyOptionsRequirement();
    _darkMode = HiveService.isDarkMode();
    _notifications = HiveService.isNotificationEnabled();
    _dailyWordNotification = HiveService.isDailyWordNotification();
    _practiceReminderNotification = HiveService.isPracticeReminderNotification();
    _streakNotification = HiveService.isStreakNotification();
    _reEngagementNotification = HiveService.isReEngagementEnabled();
    _idleReminderEnabled = HiveService.isIdleReminderEnabled();
    _idleReminderFrequency = HiveService.getIdleReminderFrequencyHours();
    _idleReminderSoundEnabled = HiveService.isIdleReminderSoundEnabled();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = info.version);
    }
  }

  /// Google requires a privacy-options entry point (EEA/UK) so users can
  /// revisit their ad-consent choices. Hidden elsewhere automatically.
  Future<void> _loadPrivacyOptionsRequirement() async {
    try {
      final required = await ConsentService().isPrivacyOptionsRequired();
      if (mounted && required) {
        setState(() => _privacyOptionsRequired = true);
      }
    } catch (_) {
      // Consent info not ready yet — tile stays hidden this session.
    }
  }

  Future<void> _showPrivacyOptions() async {
    await ConsentService().showPrivacyOptionsForm();
    // Consent choices may have changed — re-evaluate for next build.
    _loadPrivacyOptionsRequirement();
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
                activeThumbColor: AppColors.primary,
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
                  activeThumbColor: AppColors.primary,
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
                    activeThumbColor: AppColors.primary,
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
                    activeThumbColor: AppColors.primary,
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
                    activeThumbColor: AppColors.primary,
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
                    activeThumbColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('⏳ Idle Reminder'),
                    subtitle: const Text('Duolingo-style reminder when inactive'),
                    secondary: const Icon(Icons.timer_outlined, color: AppColors.primary),
                    value: _idleReminderEnabled,
                    onChanged: (val) async {
                      setState(() => _idleReminderEnabled = val);
                      await HiveService.setIdleReminderEnabled(val);
                    },
                    activeThumbColor: AppColors.primary,
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
                      title: const Text('🔊 Reminder Sound'),
                      subtitle: const Text('Play custom notification sound'),
                      secondary: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                      value: _idleReminderSoundEnabled,
                      onChanged: (val) async {
                        setState(() => _idleReminderSoundEnabled = val);
                        await HiveService.setIdleReminderSoundEnabled(val);
                      },
                      activeThumbColor: AppColors.primary,
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
              const SizedBox(height: 12),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.notification_important_outlined,
                      color: AppColors.warning),
                  title: const Text('Notification আসছে না?'),
                  subtitle: const Text(
                      'Realme/OPPO/Vivo/Xiaomi-এ অ্যাপ বন্ধ থাকলে notification বন্ধ হয়ে যায় — এখান থেকে ঠিক করুন'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BatteryOptimizationScreen()),
                    );
                  },
                ),
              ]),
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
                activeThumbColor: Theme.of(context).primaryColor,
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
              // UMP privacy-options entry point — only rendered when Google
              // requires it (e.g. EEA/UK users). Google policy compliance.
              if (_privacyOptionsRequired) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                  title: const Text('Privacy Options'),
                  subtitle: const Text('Manage how ads use your data'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: _showPrivacyOptions,
                ),
              ],
            ]),
            const SizedBox(height: 24),
            Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white60 : Colors.black45)),
            const SizedBox(height: 8),
            _buildSettingsCard([
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                title: const Text('Version'),
                subtitle: Text(_appVersion.isEmpty ? '1.0.0' : _appVersion),
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
}
