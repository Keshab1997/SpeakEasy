import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/config/app_config_model.dart';
import '../../../services/remote_config_service.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  AppConfig? _config;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Controllers for text fields
  final _forceUpdateMessageController = TextEditingController();
  final _forceUpdateVersionController = TextEditingController();
  final _forceUpdateUrlController = TextEditingController();
  final _maintenanceMessageController = TextEditingController();
  final _streakFreezeCostController = TextEditingController();
  final _dailyGoalXPController = TextEditingController();
  final _maxStreakFreezesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _forceUpdateMessageController.dispose();
    _forceUpdateVersionController.dispose();
    _forceUpdateUrlController.dispose();
    _maintenanceMessageController.dispose();
    _streakFreezeCostController.dispose();
    _dailyGoalXPController.dispose();
    _maxStreakFreezesController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await RemoteConfigService.getConfig();
      _config = config;
      _populateControllers(config);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateControllers(AppConfig config) {
    _forceUpdateMessageController.text = config.forceUpdate.message;
    _forceUpdateVersionController.text = config.forceUpdate.targetVersion;
    _forceUpdateUrlController.text = config.forceUpdate.playStoreUrl;
    _maintenanceMessageController.text = config.maintenanceMode.message;
    _streakFreezeCostController.text = config.gameplay.streakFreezeCost.toString();
    _dailyGoalXPController.text = config.gameplay.dailyGoalXP.toString();
    _maxStreakFreezesController.text = config.gameplay.maxStreakFreezes.toString();
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;

    setState(() => _saving = true);

    try {
      final updates = <String, dynamic>{
        'featureToggles': {
          'aiTeacher': _config!.featureToggles.aiTeacher,
          'games': _config!.featureToggles.games,
          'homework': _config!.featureToggles.homework,
          'sentenceAnalyzer': _config!.featureToggles.sentenceAnalyzer,
          'speaking': _config!.featureToggles.speaking,
          'listening': _config!.featureToggles.listening,
        },
        'forceUpdate': {
          'enabled': _config!.forceUpdate.enabled,
          'message': _forceUpdateMessageController.text.trim(),
          'targetVersion': _forceUpdateVersionController.text.trim(),
          'playStoreUrl': _forceUpdateUrlController.text.trim(),
        },
        'maintenanceMode': {
          'enabled': _config!.maintenanceMode.enabled,
          'message': _maintenanceMessageController.text.trim(),
        },
        'gameplay': {
          'streakFreezeCost': int.tryParse(_streakFreezeCostController.text.trim()) ?? 100,
          'dailyGoalXP': int.tryParse(_dailyGoalXPController.text.trim()) ?? 50,
          'maxStreakFreezes': int.tryParse(_maxStreakFreezesController.text.trim()) ?? 3,
        },
      };

      await RemoteConfigService.updateConfig(updates);
      await _loadConfig(); // Reload to refresh state

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuration saved successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Config'),
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadConfig,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Failed to load config:\n$_error',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadConfig, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildForm(isDark),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveConfig,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save All Changes'),
            ),
    );
  }

  Widget _buildForm(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildSectionHeader('Feature Toggles', Icons.toggle_on_outlined),
        const SizedBox(height: 12),
        ...FeatureToggles.allKeys.map((key) => _buildFeatureToggle(key, isDark)),
        const SizedBox(height: 24),
        _buildSectionHeader('Force Update', Icons.system_update_rounded),
        const SizedBox(height: 12),
        _buildForceUpdateSection(isDark),
        const SizedBox(height: 24),
        _buildSectionHeader('Maintenance Mode', Icons.construction_rounded),
        const SizedBox(height: 12),
        _buildMaintenanceSection(isDark),
        const SizedBox(height: 24),
        _buildSectionHeader('Game Settings', Icons.sports_esports_outlined),
        const SizedBox(height: 12),
        _buildGameSettingsSection(isDark),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildFeatureToggle(String key, bool isDark) {
    final enabled = _config!.featureToggles.isEnabled(key);
    final displayName = _config!.featureToggles.displayName(key);

    return Card(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: SwitchListTile(
        title: Text(displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(enabled ? 'Enabled' : 'Disabled'),
        value: enabled,
        activeColor: AppColors.primary,
        onChanged: (value) {
          setState(() {
            _config = _config!.copyWith(
              featureToggles: _config!.featureToggles._with(key, value),
            );
          });
        },
      ),
    );
  }

  Widget _buildForceUpdateSection(bool isDark) {
    return _buildSectionCard(isDark, [
      SwitchListTile(
        title: const Text('Force Update',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_config!.forceUpdate.enabled ? 'Active' : 'Inactive'),
        value: _config!.forceUpdate.enabled,
        activeColor: AppColors.primary,
        onChanged: (value) {
          setState(() {
            _config = _config!.copyWith(
              forceUpdate: ForceUpdateInfo(
                enabled: value,
                message: _config!.forceUpdate.message,
                targetVersion: _config!.forceUpdate.targetVersion,
                playStoreUrl: _config!.forceUpdate.playStoreUrl,
              ),
            );
          });
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _forceUpdateMessageController,
          decoration: const InputDecoration(
            labelText: 'Update Message',
            hintText: 'Please update to the latest version',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _forceUpdateVersionController,
                decoration: const InputDecoration(
                  labelText: 'Target Version',
                  hintText: '2.0.0',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _forceUpdateUrlController,
                decoration: const InputDecoration(
                  labelText: 'Play Store URL',
                  hintText: 'https://play.google.com/...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildMaintenanceSection(bool isDark) {
    return _buildSectionCard(isDark, [
      SwitchListTile(
        title: const Text('Maintenance Mode',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_config!.maintenanceMode.enabled
            ? 'Active — users see maintenance screen'
            : 'Inactive'),
        value: _config!.maintenanceMode.enabled,
        activeColor: AppColors.primary,
        onChanged: (value) {
          setState(() {
            _config = _config!.copyWith(
              maintenanceMode: MaintenanceModeInfo(
                enabled: value,
                message: _config!.maintenanceMode.message,
              ),
            );
          });
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _maintenanceMessageController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Maintenance Message',
            hintText: 'App is under maintenance. Please come back later.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildGameSettingsSection(bool isDark) {
    return _buildSectionCard(isDark, [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _streakFreezeCostController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Streak Freeze Cost',
                  hintText: '100',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _dailyGoalXPController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Daily Goal XP',
                  hintText: '50',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _maxStreakFreezesController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Max Streak Freezes',
            hintText: '3',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildSectionCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

/// Extension to allow copying AppConfig with modified fields
extension _AppConfigCopy on AppConfig {
  AppConfig copyWith({
    FeatureToggles? featureToggles,
    ForceUpdateInfo? forceUpdate,
    MaintenanceModeInfo? maintenanceMode,
    GameplaySettings? gameplay,
  }) {
    return AppConfig(
      featureToggles: featureToggles ?? this.featureToggles,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      gameplay: gameplay ?? this.gameplay,
    );
  }
}

/// Extension to create a modified FeatureToggles
extension _FeatureTogglesModify on FeatureToggles {
  FeatureToggles _with(String key, bool value) {
    switch (key) {
      case 'aiTeacher':
        return FeatureToggles(
          aiTeacher: value,
          games: games,
          homework: homework,
          sentenceAnalyzer: sentenceAnalyzer,
          speaking: speaking,
          listening: listening,
        );
      case 'games':
        return FeatureToggles(
          aiTeacher: aiTeacher,
          games: value,
          homework: homework,
          sentenceAnalyzer: sentenceAnalyzer,
          speaking: speaking,
          listening: listening,
        );
      case 'homework':
        return FeatureToggles(
          aiTeacher: aiTeacher,
          games: games,
          homework: value,
          sentenceAnalyzer: sentenceAnalyzer,
          speaking: speaking,
          listening: listening,
        );
      case 'sentenceAnalyzer':
        return FeatureToggles(
          aiTeacher: aiTeacher,
          games: games,
          homework: homework,
          sentenceAnalyzer: value,
          speaking: speaking,
          listening: listening,
        );
      case 'speaking':
        return FeatureToggles(
          aiTeacher: aiTeacher,
          games: games,
          homework: homework,
          sentenceAnalyzer: sentenceAnalyzer,
          speaking: value,
          listening: listening,
        );
      case 'listening':
        return FeatureToggles(
          aiTeacher: aiTeacher,
          games: games,
          homework: homework,
          sentenceAnalyzer: sentenceAnalyzer,
          speaking: speaking,
          listening: value,
        );
      default:
        return this;
    }
  }
}