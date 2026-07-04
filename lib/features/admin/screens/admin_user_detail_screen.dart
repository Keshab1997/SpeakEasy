import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../repository/admin_repository.dart';
import 'package:intl/intl.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final UserModel user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _repository = AdminRepository();
  Map<String, dynamic>? _progress;
  bool _loadingProgress = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await _repository.getUserProgress(widget.user.id);
      if (mounted) {
        setState(() {
          _progress = progress;
          _loadingProgress = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name.isEmpty ? 'User Detail' : user.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(user, isDark),
          const SizedBox(height: 20),
          _buildInfoSection(user, isDark),
          const SizedBox(height: 20),
          _buildProgressSection(isDark),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isDark) {
    final roleColor = user.role == 'admin'
        ? AppColors.purpleGradient.first
        : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: roleColor.withOpacity(0.12),
            backgroundImage:
                user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    _initials(user.name),
                    style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(user.name.isEmpty ? 'Unnamed User' : user.name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(user.email,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 8),
          Chip(
            label: Text(user.role.toUpperCase()),
            labelStyle: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            backgroundColor: roleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(UserModel user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Info',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _infoRow(Icons.calendar_today_rounded, 'Joined',
              _formatDate(user.joinedAt)),
          _infoRow(Icons.local_fire_department_rounded, 'Streak',
              '${user.streak} days'),
          _infoRow(Icons.trending_up_rounded, 'Level', user.currentLevel),
          _infoRow(Icons.admin_panel_settings_rounded, 'Role', user.role),
        ],
      ),
    );
  }

  Widget _buildProgressSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Learning Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_loadingProgress)
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            ..._progress?.entries.map((e) => _infoRow(
                  Icons.circle_rounded,
                  _formatKey(e.key),
                  '${e.value}',
                )) ??
                [
                  Center(
                    child: Text('No progress data available',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38)),
                  ),
                ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatKey(String key) {
    return key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => ' ${m.group(0)}',
    ).trim();
  }
}
